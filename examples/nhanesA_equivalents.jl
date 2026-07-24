# NHANES.jl Examples
# Julia equivalents of R nhanesA package examples

import NHANES
using DataFrames

# =============================================================================
# Listing Tables
# =============================================================================

# List examination tables for 2005-2006 cycle
# R: nhanesTables('EXAM', 2005)
NHANES.tables(:EXAM, 2005)

# Also supports full component names
NHANES.tables(:Examination, 2005)

# =============================================================================
# Exploring Table Variables
# =============================================================================

# List variables in a table
# R: nhanesTableVars('EXAM', 'BMX_D')
NHANES.variables("BMX_D")

# =============================================================================
# Importing Data Tables
# =============================================================================

# Download tables (translates coded values by default)
# R: bmx_d <- nhanes('BMX_D')
bmx_d = NHANES.download("BMX_D")

# R: demo_d <- nhanes('DEMO_D')
demo_d = NHANES.download("DEMO_D")

# =============================================================================
# Merging and Displaying Data
# =============================================================================

# Merge on SEQN (participant ID)
bmx_demo = innerjoin(demo_d, bmx_d, on = :SEQN)

# Select columns of interest
select_cols = [:RIAGENDR, :BMXHT, :BMXWT, :BMXLEG, :BMXCALF, :BMXTHICR]
first(bmx_demo[!, select_cols], 5)

# =============================================================================
# Accessing Codebooks
# =============================================================================

# Get codebook for a variable
# R: nhanesCodebook('DEMO_D', 'RIAGENDR')
NHANES.codebook("DEMO_D", :RIAGENDR)

# =============================================================================
# Custom Translation
# =============================================================================

# Download without translation to keep numeric codes
# R: bpx_d <- nhanes('BPX_D', translate=FALSE)
bpx_d = NHANES.download("BPX_D"; translate = false)

# Translate specific columns
# R: nhanesTranslate('BPX_D', c('BPXPULS', 'BPXPTY'), data=bpx_d)
NHANES.translate!(bpx_d, "BPX_D", :BPXPULS)

# Non-mutating version returns new DataFrame
bpx_labeled = NHANES.translate(bpx_d, "BPX_D", :BPXPTY)

# =============================================================================
# Downloading Multiple Tables
# =============================================================================

# List available questionnaire tables for a cycle
# R: q2007names <- nhanesTables('Q', 2007, namesonly=TRUE)
q2007 = NHANES.tables(:Q, 2007)

# Download specific tables (not all tables have XPT files available)
# R: q2007tables <- lapply(q2007names, nhanes)
alq_e = NHANES.download("ALQ_E")  # Alcohol Use
smq_e = NHANES.download("SMQ_E")  # Smoking

# =============================================================================
# Searching Variables
# =============================================================================

# Search for variables by description
# R: nhanesSearch("bladder", ystart=2001, ystop=2008)
NHANES.search("bladder"; years = 2001:2008)

# Search in specific component
# R: nhanesSearch("glucose", data_group='LAB')
NHANES.search("glucose"; component = :LAB)

# Search by exact variable name
# R: nhanesSearchVarName('BMXLEG')
NHANES.search_var_name("BMXLEG")
NHANES.search_var_name("BPXPULS"; years = 2005:2010)

# Search table names by pattern
# R: nhanesSearchTableNames('BMX')
NHANES.search_table_names("BMX")
NHANES.search_table_names("GLU"; component = :Laboratory)

# =============================================================================
# DXA Data (Dual Energy X-Ray Absorptiometry)
# =============================================================================

# List available DXA tables for a year
NHANES.dxa_tables(2005)

# Download DXA data
# R: dxx_b <- nhanesDXA(2001)
dxx_b = NHANES.dxa(2001)

# Download supplemental data (highly variable imputation)
# R: dxx_c_s <- nhanesDXA(2003, suppl=TRUE)
dxx_c_s = NHANES.dxa(2003; suppl = true)

# Note: DXA datasets contain 5 imputation sets per participant
# Analyze all 5 separately - do not average

# =============================================================================
# Historical NHANES Surveys
# =============================================================================

# Access pre-continuous NHANES data
# NHANES I (1971-1975)
NHANES.historical_tables(:nhanes1)

# NHANES II (1976-1980)
NHANES.historical_tables(:nhanes2)

# NHANES III (1988-1994)
NHANES.historical_tables(:nhanes3)

# NHANES III publishes SAS transport files, read straight into a DataFrame
ssnh3mgm = NHANES.historical_download(:nhanes3, "SSNH3MGM")

# NHANES I and II publish fixed-width text; download and parse it yourself
du4111 = NHANES.historical_file(:nhanes1, "DU4111")
