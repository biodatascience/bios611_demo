# Demonstration Makefile

build-image: Dockerfile
	sudo docker build -t bios611/bios611_demo . && touch $@
	
data/combined_wbdata.csv: build-image \
						  scripts/combine_data_sets.py \
						  data/API_SP.DYN.CBRT.IN_DS2_en_csv_v2_10402674/API_SP.DYN.CBRT.IN_DS2_en_csv_v2_10402674.csv
	docker run -d --rm \
		--user root \
		-e "UID=$UID" \
		-v $(shell pwd):/home/jovyan \
		-w /home/jovyan \
		bios611/bios611_demo \
			python scripts/combine_data_sets.py data/ 
	
results/world_map.png: data/combined_wbdata.csv \
					   scripts/generate_plots.R
	docker run -d --rm \
		--user root \
		-e "UID=$UID" \
		-v $(shell pwd):/home/jovyan \
		-w /home/jovyan \
		bios611/bios611_demo \
			Rscript scripts/generate_plots.R data/ results/ && \
	touch results/world_map.png # wait for results/world_map.png to be made
			
results/demographics_of_money.html: results/world_map.png \
									results/demographics_of_money.Rmd
	docker run -it --rm \
		--user root \
		-e "UID=$UID" \
		-v $(shell pwd)/results/:/home/jovyan \
		-w /home/jovyan/ \
		bios611/bios611_demo \
			Rscript -e "rmarkdown::render('demographics_of_money.Rmd', output_file='demographics_of_money.html')"