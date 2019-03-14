FROM jupyter/datascience-notebook:7db1bd2a7511 

RUN Rscript -e "install.packages('maps', repos='https://cloud.r-project.org')"

