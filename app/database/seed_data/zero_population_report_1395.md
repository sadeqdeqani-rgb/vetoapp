# Census 1395 zero-population settlement data

- Provincial workbooks read: 31
- Census settlement-code records read: 88,283
- Census records with population 0: 35,254
- Distinct province/county/name groups that are all-zero: 33,521
- Distinct same-name groups with both zero and positive census records: 776
- Distinct province/name groups with only zero-population records: 30,192
- Province/name groups with zero and positive population records (excluded): 2,058
- Safe province/name targets after excluding same-named cities: 30,177
- Province/name targets excluded because they also name a city: 15
- Current village seed entries matching a safe target: 27,576
- Distinct safe province/county/name database targets: 33,516
- All-zero names also used by a city record (excluded from name-based migration): 5
- All-zero groups not present in the current village seed list: 6,618

The corrected server migration uses province/name because county boundaries changed since the 1395 census. It only considers province/name pairs whose every census record is zero, excludes names used by cities, and requires a unique matching settlement in the live database. Province/name pairs with any positive census record are in `zero_population_province_mixed_names_1395.tsv` and are excluded.

## Matched seed entries by province

| Province | Entries |
|---|---:|
| آذربایجان شرقی | 350 |
| آذربایجان غربی | 453 |
| اردبیل | 148 |
| اصفهان | 1,489 |
| البرز | 124 |
| ایلام | 372 |
| بوشهر | 210 |
| تهران | 241 |
| خراسان جنوبی | 1,645 |
| خراسان شمالی | 443 |
| خوزستان | 2,323 |
| زنجان | 241 |
| سمنان | 1,415 |
| سیستان وبلوچستان | 2,221 |
| فارس | 3,901 |
| قزوین | 178 |
| قم | 125 |
| لرستان | 411 |
| مازندران | 648 |
| مرکزی | 383 |
| هرمزگان | 519 |
| همدان | 116 |
| کردستان | 195 |
| کرمان | 5,479 |
| کرمانشاه | 545 |
| کهگیلویه وبویراحمد | 533 |
| گلستان | 37 |
| گیلان | 252 |
| یزد | 2,579 |
