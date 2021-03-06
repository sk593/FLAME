test_that("excluding outcome doesn't change matches", {
  data <- gen_data(n = 250, p = 3)
  holdout <- gen_data(n = 250, p = 3)
  flout_w_outcome <- FLAME(data = data, holdout = holdout)
  flout_wo_outcome <- FLAME(data = dplyr::select(data, -outcome), holdout = holdout)
  expect_identical(flout_w_outcome$MGs, flout_wo_outcome$MGs)
})
