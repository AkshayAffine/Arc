install.packages("lubridate")
install.packages("stats")
install.packages("forecast")
install.packages("tseries")
install.packages("Ecdat")
install.packages("DataCombine")
install.packages("data.table")
library(lubridate)
library(stats)
library(forecast)
library(tseries)
library(Ecdat)
library(DataCombine)
library(data.table)
-------------------------------------------------------------------------
## Import analytical dataset for baseline calculation
-------------------------------------------------------------------------
  
getwd()

setwd("D:/03 Projects 16-17/TPC_Arcadia/Exponential Smoothing/Technique")

ES_AD <- read.csv("es_base_dept_file_1.csv",header = FALSE,stringsAsFactors = FALSE)

colnames(ES_AD) <- c("fiscal_year","fiscal_week","Period","MERCHANDISE_KEY","Cat_key","GROSS_SALES_UNITS")

-------------------------------------------------------------------------
## Creation of analytical dataset for seasonality calculation
-------------------------------------------------------------------------  
  
Season_AD <- data.table(ES_AD)
Season_AD <- Season_AD[,j=list(sale_unit_gross = sum(GROSS_SALES_UNITS))
               ,by = c("fiscal_year","fiscal_week","Period","Cat_key")]

a <- unique(Season_AD$Cat_key)

season_final <- data.frame()
------------------------------------------------------------------------
## Calculating seasonality index for each category  
------------------------------------------------------------------------
for (i in 1:length(a))
  
{
  Season_interim <- Season_AD[Season_AD$Cat_key == a[i]]
  
  ts1 <- ts(Season_interim$sale_unit_gross,frequency = 52)
    
  product_ts_dec <- decompose(ts1,type = "multiplicative")
  
  product_ts = as.numeric(product_ts_dec$seasonal)
  
  Season_interim <- data.frame(Season_interim,product_ts)
  
  season_final <- rbind(season_final,Season_interim)
}

ES_AD_final <- merge(ES_AD,season_final[c("fiscal_year","fiscal_week","Period","Cat_key","product_ts")],by = c("fiscal_year","fiscal_week","Period","Cat_key"),all.x=T)

ES_AD_final$product_ts[ES_AD_final$product_ts==0] <- 1

ES_AD_final$S_R_forecast <- with(ES_AD_final,ES_AD_final$GROSS_SALES_UNITS/ES_AD_final$product_ts)

ES_AD_final <- ES_AD_final[order(ES_AD_final[,5], ES_AD_final[,1],ES_AD_final[,2],ES_AD_final[,3]),]
--------------------------------------------------------------------------  
## Defining ES Functions
--------------------------------------------------------------------------
  
fcast <- function(prev_act, prev_fcast, prev_alpha)
{
  return (prev_alpha*prev_act + (1-prev_alpha)*prev_fcast)
}

ES.A <- function(err, prev_A, const)
{
  return (const*err + (1-const)*prev_A)
}

ES.M <- function(err, prev_M, const)
{
  return (const*abs(err) + (1-const)*prev_M)
}

ES.alpha <- function(curr_A, curr_M)
{
  output = abs(curr_A/curr_M)
  if(is.na(output)){
    output = 1
  }
  
  return(output)
}

--------------------------------------------------------------------
## Exponential smoothing with adaptive rate
--------------------------------------------------------------------
  
b <- unique(ES_AD_final$MERCHANDISE_KEY)

ES_final <- data.frame()

for (i in 1:length(b))
  
{
  ES_interim <- ES_AD_final[ES_AD_final$MERCHANDISE_KEY == b[i],]

  ES_null <- as.data.frame(matrix(ncol = 8))
  ES_null[1,] <- ES_interim[136,]
  ES_null[1,3] <- 137
  ES_null[1,6:8] <- 0
  colnames(ES_null) <- colnames(ES_interim)
  ES_interim <- rbind(ES_interim,ES_null)
  
es.fcast <- rep(0, 137)
err <- rep(0, 137)
err[1] <- ES_interim$S_R_forecast[1] - es.fcast[1]
MAPE <- rep(0, 137)
MAPE[1] <- err[1]/ES_interim$S_R_forecast[1]
A.array <- rep(0, 137)
M.array <- rep(0, 137)
alpha.array <- rep(1, 137)

for(i in 2:137)
{
  es.fcast[i] <- fcast(ES_interim$S_R_forecast[i-1], es.fcast[i-1], alpha.array[i-1])
  err[i] <- ES_interim$S_R_forecast[i] - es.fcast[i]
  MAPE[i] <- err[i]/ES_interim$S_R_forecast[i]
  A.array[i] <- ES.A(err = err[i],prev_A = A.array[i-1], const = 0.2)
  M.array[i] <- ES.M(err = err[i],prev_M = M.array[i-1], const = 0.2)
  alpha.array[i] <- ES.alpha(A.array[i], M.array[i])
}

ES_interim <- data.frame(ES_interim,es.fcast,err)

ES_final <- rbind(ES_final,ES_interim)

}

write.table(ES_final,"final_result_dept_2.txt",sep = ",",row.names = FALSE)


res <- sum(ES_final$S_R_forecast)
