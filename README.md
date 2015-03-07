# ODF

Scripts and tools to help in parsing the [Olympic Data Feed](http://odf.olympictech.org) from the International Olympic Committee.

## Competitions

Files that apply differently to different competitions, such as Common Codes, are organized under the `competitions` directory.

### Common Codes / Sport Codes

These codes are delivered via `.xlsx` file through `odf.olympictech.org`. Since this file is not easily parsed by applications, the code data has been transformed into `csv` and `json` files. They can be found in the following directories:

`competitions/[COMPETITION]/codes/[VERSION]/csv|json`

For example, the json version of v7.0 of the codes for the Rio Olympics can be found at `competitions/OG2016/codes/7.0/json`.

These directories contain files that are a direct mapping to the tabs found in the Common Codes and Sport Codes spreadsheets, and named identically but with any `ODF`, `GL`, `OG` or `PG` prefix stripped for simplicity. For example, the Country codes from the tab called `ODF_GL_Country` are exported to `Country.csv` and `Country.json`.

#### Updating the codes

the `scripts/codes.rb` file is provided to generate new codes based on later releases of the `.xlsx` files. You will need to have Ruby bundler installed, and run `bundle install` first. Then run the following:

`./scripts/codes.rb [PATH TO .xlsx FILE] [COMPETITION] [VERSION]`

e.g., `./scripts/codes.rb Rio\ 2016\ OLY\ Sport\ Codes.zip OG2016 7.0`

## Licensing

Unless otherwise noted, data sourced from the odf.olympictech.org website is copyright the International Olympic Committee, under the terms layed out inside the `ODF_LICENSE` file. All use of such data is subject to the acceptance of those terms and conditions.

All other code is copyright The New York Times Company, and is released with the Apache 2.0 License.
