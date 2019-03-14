## Demo project for BIOS 611

Data for this project was obtained from the website of the World Bank.

Birth Rate: https://data.worldbank.org/indicator/SP.DYN.CBRT.IN?view=chart

GDP: https://data.worldbank.org/indicator/NY.GDP.MKTP.CD

To re-produce the figures and HTML output, run:

`make results/demographics_of_money.html`

This will begin by building a docker container, then sequentially
process the data using Python, generate the figures using R, 
and format the HTML document using Rmd. The project flow is 
controlled by Make.
