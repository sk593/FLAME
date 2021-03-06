# X is the subset of the data frame containing the continuous covariates
bin_continuous_covariates <- function(X, rule, type) {
  n <- nrow(X)
  if (rule == 'sturges') {
    bin_fun <- function(x) {
      (max(x, na.rm = TRUE) - min(x, na.rm = TRUE)) / (log(n, base = 2) + 1)}
  }
  else if (rule == 'scott') {
    bin_fun <- function(x) 3.5 * sqrt(var(x, na.rm = TRUE)) / (n ^ (1 / 3))
  }
  else if (rule == 'fd') {
    bin_fun <- function(x) 2 * IQR(x, na.rm = TRUE) / (n ^ (1 / 3))
  }
  else {
    stop(paste('Unrecognized binning rule.',
               'Please supply one of "sturges", "scott", or "fd".'))
  }

  is_continuous <- which(!sapply(X, is.factor))
  if (length(is_continuous) == 0) {
    return(X)
  }
  if (type == 'data') {
    warning(paste('Binning continuous covariates. This is not recommended;',
                  'users are encouraged to use methods specifically',
                  'designed for continuous covariates.'))
  }

  X_cont <- X[, is_continuous, drop = FALSE]
  cov_names <- colnames(X_cont)
  bin_sizes <- sapply(X_cont, bin_fun)
  ranges <- sapply(X_cont, function(x) {
    max(x, na.rm = TRUE) - min(x, na.rm = TRUE)})
  n_bins <- ceiling(ranges / bin_sizes)

  X_cont <-
    lapply(1:ncol(X_cont), function(i) {
      cut(X_cont[, i], breaks = n_bins[i], labels = 0:(n_bins[i] - 1))
    }) %>%
    as.data.frame() %>%
    `colnames<-`(cov_names)

  X[, is_continuous] <- X_cont

  return(X)
}

# NULL default for holdout set
sort_cols <-
  function(df, outcome_in_data, treated_column_name, outcome_column_name,
           binning_method, type, is_missing = NULL) {

  n_covs <- ncol(df[[1]]) - 1 - outcome_in_data # Ignore treatment, outcome
  n_df <- length(df) # Always pass in a list of data frames

  # Treatment and outcome will be constant across imputations
  treatment_col <-
    df[[1]] %>%
    dplyr::select(!!rlang::enquo(treated_column_name))

  if (type == 'holdout' | (type == 'data' & outcome_in_data)) {
    outcome_col <-
      df[[1]] %>%
      dplyr::select(!!rlang::enquo(outcome_column_name))
  }

  n <- nrow(df[[1]])

  treatment_col_ind <- which(colnames(df[[1]]) == treated_column_name)
  outcome_col_ind <- which(colnames(df[[1]]) == outcome_column_name)
  covariates <-
    which(!(1:ncol(df[[1]]) %in% c(treatment_col_ind, outcome_col_ind)))

  # For all imputed data sets
  for (i in 1:n_df) {
    tmp_df <- df[[i]]

    if (type == 'holdout' | (type == 'data' & outcome_in_data)) {
      tmp_df <-
        tmp_df[, covariates] %>%
        cbind(outcome_col) %>%
        cbind(treatment_col)
    }
    else {
      tmp_df <-
        tmp_df[, covariates] %>%
        cbind(treatment_col)
    }

    tmp_df[, 1:n_covs] <-
      bin_continuous_covariates(tmp_df[, 1:n_covs, drop = FALSE],
                                rule = binning_method, type)

    # Number of levels of each covariate
    n_levels <- sapply(tmp_df[, 1:n_covs, drop = FALSE], nlevels)
    if (any(n_levels == nrow(tmp_df))) {
      warning(paste("It looks like you might have passed in a continuous",
                    "variable as a factor; you won't make any matches on it.",
                    "If you want this variable to be binned, you should pass",
                    "it as numeric; otherwise, don't include it at all."))
    }

    cov_names <- colnames(tmp_df)[1:n_covs]

    # Sorting data column names
    if (type == 'holdout' | (type == 'data' & outcome_in_data)) {
      colnames(tmp_df) <- c(cov_names, 'outcome', 'treated')
    }
    else {
      colnames(tmp_df) <- c(cov_names, 'treated')
    }

    if (type == 'data') {
      for (j in 1:n_covs) {
        levels(tmp_df[, j]) %<>% c('*')
      }
    }

    # covs denotes the covariates currently being matched on
    covs <- 1:n_covs

    # Denote whether a unit is matched and to how many others, respectively
    if (type == 'data') {
      tmp_df$matched <- rep(FALSE, n)
      tmp_df$weight <- rep(0, n)
      tmp_df$missing <- is_missing
    }

    df[[i]] <- tmp_df
  }
  return(list(df = df,
              covs = covs,
              n_covs = n_covs,
              cov_names = cov_names))
}
