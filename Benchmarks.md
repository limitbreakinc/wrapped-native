# Benchmarking WETH9 vs Wrapped Native

| Benchmark                           | WETH9  | Wrapped Native | Savings |
|-------------------------------------|--------|----------------|---------|
| `deposit`                           | 23974  | 23866          | 108     |
| `withdraw`                          | 13940  | 13545          | 395     |
| `totalSupply`                       | 343    | 550            | -207    |
| `approve`                           | 24420  | 24207          | 213     |
| `transfer`                          | 29962  | 29335          | 627     |
| `transferFrom` (Self)               | 29832  | 29351          | 481     |
| `transferFrom` (Operator Allowance) | 35648  | 34560          | 1088    |
| `transferFrom` (Operator Unlimited) | 32125  | 31609          | 516     |