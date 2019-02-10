The customerRelationship R/Rcpp script calculates the overall customer relationship timeline per customer from many 
fragmented activity inputs. It is useful for CRMs that are very fragmented.

This might turn usefull for marketing analysts that have interest in 
 - the overall length of a relationship between a subject and a company
 - loyatly outcomes of a campaign
 - customer tenure
 - churn/survival analysis
 
 and other related maketing applications.
 

The scripts turns smaller fragments of orders/positions in a given CRM model (say SAP) and turns them into periods where the 
subject has been active without a day pause in relationship as follow in the example.

Sample data:

```R
dat <- data.frame(
  ID = c(1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 
         1L, 1L, 1L, 1L, 1L, 1L, 1L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 
         2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 
         2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 3L, 3L, 3L, 3L, 4L, 4L, 4L, 5L, 5L, 5L, 6L, 7L, 7L, 7L),
  From = structure(c(10859, 12039, 14102, 14782, 14783, 14784, 14785, 14786, 14789, 14791, 
                    14792, 14793, 14795, 14796, 14797, 14798, 14799, 14800, 14803, 14807, 
                    14811, 14817, 14818, 14820, 14821, 14824, 14827, 14828, 14834, 14835, 
                    14838, 14841, 14845, 10859, 10862, 10865, 10865, 10865, 12084, 12084, 
                    12084, 12084, 12658, 13421, 14761, 14863, 14863, 14863, 14863, 14863, 
                    14888, 14973, 14980, 14980, 14980, 14980, 14980, 14980, 14993, 14994, 
                    14998, 15009, 15051, 15355, 15355, 15355, 15358, 15358, 15358, 15358, 
                    15358, 15387, 15387, 15388, 15388, 16416, 16452, 16464, 16478, 16478, 
                    16974, 17116, 17116, 17122, 17122, 17522, 14316, 14471, 14563, 15608, 
                    10865, 17709, 17737, 13027, 14473, 17190, 10859, 10865, 15219, 16736), class = "Date", tzone = "Europe/Berlin"),
  To = structure(c(14781, 15339, 15964, 14782, 14783, 14784, 14785, 14788, 14790, 14791, 
                   14792, 14794, 14795, 14796, 14797, 14798, 14799, 14802, 14806, 14810, 
                   14816, 14817, 14819, 14820, 14823, 14826, 14827, 14833, 14834, 14837, 
                   14840, 14844, 14846, 14979, 14979, 14979, 14979, 14979, 14979, 15354, 
                   14972, 14862, 14760, 15354, 14993, 15354, 15354, 15354, 15354, 15354, 
                   15354, 14992, 15354, 15354, 15354, 15354, 15354, 15354, 14997, 15354, 
                   15008, 15050, 15354, 16415, 15386, 15357, 15386, 2932896, 16973, 
                   2932896, 2932896, 15387, 15387, 16451, 16463, 2932896, 16477, 16477, 
                   17115, 17115, 2932896, 17121, 17121, 2932896, 17521, 2932896, 14329, 
                   14562, 15064, 15621, 15886, 17709, 17737, 17189, 14533, 17256, 15430, 
                   15399, 15227, 2932896), class = "Date", tzone = "Europe/Berlin"),
  CharacteristicBeg = c("f", "a", "b", "f", "f", "f", "f", "f", "f", "f", "f", "f", "f", "f", 
                        "f", "f", "f", "f", "f", "f", "f", "f", "f", "b", "b", "b", "b", "b", 
                        "b", "b", "b", "b", "b", "a", "a", "a", "a", "a", "a", "a", "a", "a", 
                        "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", 
                        "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", 
                        "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", 
                        "a", "a", "a", "b", "b", "b", "a", "c", "c", "a", "d", "a", "a", "a", 
                        "b", "e"),
  CharacteristicEnd1 = c(NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, 
                         NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, 
                         NA, NA, NA, NA, NA, NA, NA, NA, NA, 5L, NA, 5L, 5L, 5L, 5L, 5L, 5L,
                         NA, NA, 5L, 5L, 5L, 5L, 5L, NA, 5L, NA, NA, NA, NA, NA, NA, NA, NA, 
                         NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, 
                         NA, 1L, 2L, 3L, 1L, 3L, 2L, NA, NA, 2L, 3L, 3L, 6L, 1L, NA), 
  CharacteristicEnd2 = c(NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, 
                         NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, 
                         NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, 
                         NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, 
                         NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, 
                         NA, NA, NA, NA, NA, NA, 2L, 2L, NA, NA, NA, NA, NA, NA, NA)
)
```
The data contains column ID or the customer identifier, the From and To of the individual orders, CharacteristigBeg which is 
the feature taken from the beginning of the relationship that I am interested in and the last two variables (CharacteristicEnd1 and 
CharacteristicEnd2) show the characteristics from the end of the relationship that I want to include in the resulting timeline. 
Adding more features from begin or end of the relationship is a question of adjusting the script. 

Given the data structure, the customer relationship timeline can be computed as follows:
```R
CustomerRelationshipTimeline(dat)
```


