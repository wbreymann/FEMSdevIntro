# The followoing docker container must be running:
# - actus risk server 
# - mongodb 
# - actus cash flow server (actus server rf20) 
# Will be created by executing quickstart

# install FEMSdevBase package
devtools::install_github("fnparr/FEMSdevBase@gian_dev") # subject to change
# load package
library(FEMSdevBase)

# clean session environment
rm(list=ls())


# Riskserver tests ---------------------------------------------------------
# Tests communication with the risk server
# Similar to those in quickstart
## Load Reference Indexes
rfx1 <- sampleReferenceIndex("./data/UST5Y_fallingRates.csv","UST5Y_fallingRates", "Ust_5Yf",100)
rfx2 <- sampleReferenceIndex("./data/UST5Y_steadyRates.csv","UST5Y_steadyRates", "Ust_5Ys",100)

url <- "http://localhost:8082/"

# Reference Index Server API check
putReferenceIndex(url,rfx1)
putReferenceIndex(url,rfx2)
findReferenceIndex(url,"UST5Y_fallingRates")
findReferenceIndex(url,"UST5Y_steadyRates")
findAllReferenceIndexes(url)
deleteReferenceIndex(url,"UST5Y_fallingRates")
findAllReferenceIndexes(url)
putReferenceIndex(url,rfx1)
findAllReferenceIndexes(url)

## PrepaymentModel Server API check
evTimes <- c("2015-03-01T00:00:00", "2015-09-01T00:00:00", "2016-03-01T00:00:00")
d1 <- c(0.03, 0.025, 0.02, 0.015, 0.01, 0.0, -0.05)
# 0.03,0.025,0.02,0.015,0.01,0.0,-0.05
d2 <- c(0,1,2,3,5,10)
# 0,1,2,3,5,10
data <- rbind(c(0.01, 0.05, 0.1, 0.07, 0.02, 0),
              c(0.01, 0.04, 0.8, 0.05, 0.01, 0),
              c(0, 0.02, 0.5, 0.03, 0.005, 0),
              c(0, 0.01, 0.3, 0.01, 0, 0),
              c(0, 0.01, 0.2, 0, 0, 0),
              c(0, 0, 0.1, 0, 0, 0),
              c(0, 0, 0, 0, 0, 0))

putTwoDimensionalPrepaymentModel(url, "ppm01", "Ust_5Yf", evTimes, d1, d2, data)
findAllTwoDimensionalPrepaymentModels(url)
findTwoDimensionalPrepaymentModel(url, "ppm01")
deleteTwoDimensionalPrepaymentModel(url, "ppm01")
putTwoDimensionalPrepaymentModel(url, "ppm01", "Ust5Yf", evTimes, d1, d2, data)
findAllTwoDimensionalPrepaymentModels(url)

## Scenario Server API check
referenceIndexes <- c("UST5Y_fallingRates", "UST5Y_steadyRates")
prePayments2d <- c("ppm01")
putScenario(url, "scn01", referenceIndexes, prePayments2d)
findAllScenarios(url)
findScenario(url, "scn01")
deleteScenario(url, "scn01")
putScenario(url, "scn01", referenceIndexes, prePayments2d)
findAllScenarios(url)

## Empty Server
# Notice that there is no "deleteAll" function
# Scenarios can only be deleted individually
deleteScenario(url, "scn01")
deleteTwoDimensionalPrepaymentModel(url, "ppm01")
deleteReferenceIndex(url,"UST5Y_fallingRates")
deleteReferenceIndex(url,"UST5Y_steadyRates")
findAllScenarios(url)
findAllTwoDimensionalPrepaymentModels(url)
findAllReferenceIndexes(url)


## Demonstration of the simulation and analysis work flow --------------------

### Overview of the workflow: Possibly as separate text

rm(list=ls())
# Step 1: import yaml file with the accounts tree
pt <- getwd()
accountsTree <- AccountsTree(paste(pt, "data/modelBankLAM.yaml",sep="/"))
print(accountsTree$root,"actusCIDs", "nodeID")

# Step 2: Import ACTUS contract definitions for the Financial Model Portfolio
ptf   <-  csvx2ptf(paste(pt, "data/fmTestPortfolioLAM.csv",sep="/"))
#unlist(ptf$contracts[[1]]$contractTerms)

### Missing: show function for portfolio

# Step 4: Create a Timeline setting Status and report dates, period etc
tl <- Timeline(statusDate = "2023-01-01", monthsPerPeriod = 6, reportCount=3,
               periodCount = 6)

# Step 5: create FinancialModel instance with this, ptf, accntsTree, tl
#  5.1  set up identifier, descriptors  and other scalar fields
fmID <- "fm001"
fmDescr <- "test Financial Model logic with example"
entprID <- "modelBank01"
currency <- "USD"

serverURL <- "http://localhost:8083/"
# serverURL <- "https://dadfir3-app.zhaw.ch/"
# serverURL <- "http://ractus.ch:8080/"

# 5.2 create the financialModel
?initFinancialModel
fm <- initFinancialModel(fmID=fmID, fmDescr= fmDescr, entprID = entprID,
                         accntsTree = accountsTree, ptf = ptf, curr = currency,
                         timeline = tl, serverURL = serverURL
)
class(fm)

# Step 6 gather scenario data and add a scenarioAnalysis to this financialModel
# 6.1 Gather reference index projections for MarketObjectCodes in this scenario
rfx <- sampleReferenceIndex(paste(pt, "data/UST5Y_fallingRates.csv",sep="/"),"UST5Y_fallingRates", "YC_EA_AAA",100)
# The 100 parameter is the base level for JSON
marketData <-list(rfx)
# create a sample Yieldcurve
ycID <- "yc001"
rd <- "2023-10-31"
tr <-  c(1.1, 2.0, 3.5 )/100
names(tr) <- c("1M", "1Y", "5Y")
dcc <- "30E360"
cf <- "CONTINUOUS"
ycsample <- YieldCurve(ycID,rd,tr,dcc,cf)
# 6.1 addSenarioAnaysis( ) with this scnID and risk factors
#     will set fm$currentScenarioAnalysis to be this
?addScenarioAnalysis
addScenarioAnalysis(fm = fm, scnID= "UST5Y_fallingRates", rfxs = marketData,
                    yc = ycsample)
fm$currentScenarioAnalysis$scenarioID

# Step 7: add indexes to riskserver and create scenario
riskURL <- "http://localhost:8082/"
putReferenceIndex(riskURL,rfx)
findReferenceIndex(riskURL,"UST5Y_fallingRates")

evTimes <- c("2015-03-01T00:00:00", "2015-09-01T00:00:00", "2016-03-01T00:00:00")
d1 <- c(0.03, 0.025, 0.02, 0.015, 0.01, 0.0, -0.05)
d2 <- c(0,1,2,3,5,10)
data <- rbind(c(0.01, 0.05, 0.1, 0.07, 0.02, 0),
              c(0.01, 0.04, 0.8, 0.05, 0.01, 0),
              c(0, 0.02, 0.5, 0.03, 0.005, 0),
              c(0, 0.01, 0.3, 0.01, 0, 0),
              c(0, 0.01, 0.2, 0, 0, 0),
              c(0, 0, 0.1, 0, 0, 0),
              c(0, 0, 0, 0, 0, 0))

putTwoDimensionalPrepaymentModel(riskURL, "ppm01", "YC_EA_AAA", evTimes, d1, d2, data)
findAllTwoDimensionalPrepaymentModels(riskURL)
findTwoDimensionalPrepaymentModel(riskURL, "ppm01")

putScenario(riskURL, "scn01", c("UST5Y_fallingRates"), c("ppm01"))
findScenario(riskURL, "scn01")
findAllScenarios(riskURL)

# Step 8: generateEvents( ) to simulate the fm portfolio using a  risk scenario
#         set by addScenarioAnaysis()
?generateEvents
msg1 <- generateEvents(host = fm, scenarioID = "scn01", simulateToDate = "2028-01-01", monitoringTimes = list())

# Step 8 events2dfByPeriod() - organize the cashflow events into period buckets
msg2 <- events2dfByPeriod(host=fm)

# step 9 nominalValueReports(host = fm)
msg3 <- nominalValueReports(host = fm)

# Step 10  accountsTree aggregation of NominalValue reports
msg4 <- accountNMVreports(host = fm)
getNMVreports(fm)
showNMVreports(fm)
showContractNMVs(fm)

#step 11
msg5 <- liquidityReports(host = fm )

#step 12
msg6 <- accountLQreports(host = fm)
getLQreports(fm)
showLQreports(fm)
showContractLQs(fm)

#step 13
msg7 <- netPresentValueReports(host = fm)

#step 14
msg6 <- accountNPVreports(host = fm)
getNPVreports(fm)
showNPVreports(fm)
showContractNPVs(fm)
print(fm$accountsTree$root,"actusCIDs")

deleteScenario(riskURL, "scn01")
deleteReferenceIndex(riskURL,"UST5Y_fallingRates")
deleteTwoDimensionalPrepaymentModel(riskURL, "ppm01")


# test changes of generateEvents to single Ptf and contract call

rm(list=ls())
pt <- getwd()

# Step 2: Import ACTUS contract definitions for the Financial Model Portfolio
rfx_falling <- sampleReferenceIndex(paste(pt, "data/UST5Y_fallingRates.csv",sep="/"),"UST5Y_fallingRates", "YC_EA_AAA",100)
serverURL = "http://localhost:8083/"

ptf   <-  samplePortfolio(paste(pt, "data/fmTestPortfolioLAM.csv",sep="/"))

# populate the risk server with the reference index
riskURL <- "http://localhost:8082/"
putReferenceIndex(riskURL,rfx_falling)
findReferenceIndex(riskURL,"UST5Y_fallingRates")

evTimes <- c("2015-03-01T00:00:00", "2015-09-01T00:00:00", "2016-03-01T00:00:00")
d1 <- c(0.03, 0.025, 0.02, 0.015, 0.01, 0.0, -0.05)
d2 <- c(0,1,2,3,5,10)
data <- rbind(c(0.01, 0.05, 0.1, 0.07, 0.02, 0),
              c(0.01, 0.04, 0.8, 0.05, 0.01, 0),
              c(0, 0.02, 0.5, 0.03, 0.005, 0),
              c(0, 0.01, 0.3, 0.01, 0, 0),
              c(0, 0.01, 0.2, 0, 0, 0),
              c(0, 0, 0.1, 0, 0, 0),
              c(0, 0, 0, 0, 0, 0))

putTwoDimensionalPrepaymentModel(riskURL, "ppm01", "YC_EA_AAA", evTimes, d1, d2, data)
findAllTwoDimensionalPrepaymentModels(riskURL)
findTwoDimensionalPrepaymentModel(riskURL, "ppm01")

putScenario(riskURL, "scn01", c("UST5Y_fallingRates"), c("ppm01"))
findScenario(riskURL, "scn01")
findAllScenarios(riskURL)

evs <- generateEvents(ptf = ptf,serverURL = serverURL, scenarioID = "scn01", simulateToDate = "2028-01-01", monitoringTimes = list())
evs

eventsLoL2DF(evs)

cnt1 <- loan(ctype = "ANN",start = "2015-01-01",maturity ="3 years" ,nominal = 1000,coupon = 0.05,paymentFreq = "3 months",role = "RPA")
cnt2 <- loan(ctype = "LAM",start = "2025-01-01",maturity ="3 years" ,nominal = 1000,coupon = 0.05,paymentFreq = "3 months",role = "RPA")
evs1 <- generateEventSeries(contract = cnt1, serverURL = serverURL, scenarioID = "scn01", simulateToDate = "2028-01-01", monitoringTimes = list())
evs2 <- generateEventSeries(contract = cnt2, serverURL = serverURL, scenarioID = "scn01", simulateToDate = "2028-01-01", monitoringTimes = list("2026-01-01","2027-01-01", "2025-06-01"))

cashflowPlot(evs1)
cashflowPlot(evs2)

evs1
evs2
deleteScenario(riskURL, "scn01")
deleteReferenceIndex(riskURL,"UST5Y_fallingRates")
deleteTwoDimensionalPrepaymentModel(riskURL, "ppm01")
findAllScenarios(riskURL)
findAllReferenceIndexes(riskURL)
findAllTwoDimensionalPrepaymentModels(riskURL)

