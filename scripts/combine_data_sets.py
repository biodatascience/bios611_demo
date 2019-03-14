import sys
import os
import pandas as pd

# Path to data dir provided on command line 
# upon execution of this script
DATA_DIR = sys.argv[1]

# Initialize dictionary to store data
data_dict = {'birthrate':0, 
			 'gdp':0, 
			 'pop_over_65':0}
			 
# Read CSV into data frames
# Birth rate per 1,000 people
birthrate_f = os.path.join(DATA_DIR, 
							   'API_SP.DYN.CBRT.IN_DS2_en_csv_v2_10402674', 
							   'API_SP.DYN.CBRT.IN_DS2_en_csv_v2_10402674.csv')
if os.path.isfile(birthrate_f):
	data_dict['birthrate'] = pd.read_csv(birthrate_f, sep=',', skiprows=4)

# GDP in current US dollars 
gdp_f = os.path.join(DATA_DIR, 
							   'API_NY.GDP.MKTP.CD_DS2_en_csv_v2_10399837', 
							   'API_NY.GDP.MKTP.CD_DS2_en_csv_v2_10399837.csv')
if os.path.isfile(gdp_f):
	data_dict['gdp'] = pd.read_csv(gdp_f, sep=',', skiprows=4)	

# Population age 65 and above as percent of total population
pop_over_65_f = os.path.join(DATA_DIR, 
							   'API_SP.POP.65UP.TO.ZS_DS2_en_csv_v2_10403170', 
							   'API_SP.POP.65UP.TO.ZS_DS2_en_csv_v2_10403170.csv')
if os.path.isfile(pop_over_65_f):
	data_dict['pop_over_65'] = pd.read_csv(pop_over_65_f, sep=',', skiprows=4)		

# Replace data codes with readable labels
label_dict = {'SP.POP.65UP.TO.ZS':'Percent.Pop.Over.65',
			  'NY.GDP.MKTP.CD':'GDP.Current.US.Dollars',
			  'SP.DYN.CBRT.IN':'Births.Per.1000'}
	
# Melt into long form and combine into single dataframe
data_list = []
for k in data_dict.keys():
	# Remove the last, useless column 
	data_dict[k] = data_dict[k][data_dict[k].columns[:-1]]
	
	# Reshape (AKA "melt") into long form
	data_list.append( pd.melt(data_dict[k], id_vars=['Country Name',
												     'Country Code',
												     'Indicator Name',
												     'Indicator Code'],
									        var_name='year', 
											value_name='value')
					)

combo_df = pd.concat(data_list)
combo_df['Indicator Code'] = combo_df['Indicator Code'].apply(lambda x: label_dict[x])
combo_df.columns = ['Country.Name', 'Country.Code', 'Indicator.Name', 'Indicator.Code', 'Year', 'Value']

# Check DF shape, to be sure everything worked ok
# print(combo_df.shape)
# print(combo_df.tail())

# Write combined dataframe to file
combo_df.to_csv(os.path.join(DATA_DIR, 'combined_wbdata.csv'), sep='\t', index=False)
