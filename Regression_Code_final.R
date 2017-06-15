#Clear workspace
rm(list=ls())

#Add libraries
library(RODBC)
library(plyr)
library(dplyr)

#Set working directory
getwd()
setwd("C:\\Users\\Muppalla Manaswini\\Documents\\tpc\\0602\\results")

#VIF function
vif <- function(object, ...)
  UseMethod("vif")
vif.default <- function(object, ...)
  stop("No default method for vif. Sorry.")

vif.lm <- function(object, ...) {
  V <- summary(object)$cov.unscaled
  Vi <- crossprod(model.matrix(object))
  nam <- names(coef(object))
  if(k <- match("(Intercept)", nam, nomatch = F)) {
    v1 <- diag(V)[-k]
    v2 <- (diag(Vi)[-k] - Vi[k, -k]^2/Vi[k,k])
    nam <- nam[-k]
  } else {
    v1 <- diag(V)
    
    v2 <- diag(Vi)
    warning("No intercept term detected. Results may surprise.")
  }
  nam__mod <- nam[nam %in% colnames(V)]
  v3 <- v2[c(nam__mod)]
  structure(v1*v3, names = nam__mod)
}



#Create RODBC connection
conn <- odbcConnect(dsn='TPC_Arcadia', uid='sa', pwd='test@123')


#Import Regression AD
#########use the final table name from regression code#######
reg_AD <- sqlQuery(conn, "select * from Regression_ad_type_1_changed where Dept_Desc in ('56 JERSEY','05 FORMAL TOPS','07 DRESSES','74 CASUAL BTMS')",stringsAsFactors=F)

#df<-data.frame(reg_AD %>% group_by(cluster_key) %>% summarise(rows=n()))
#write.csv(df,'Rows_for_cluster.csv', row.names = FALSE)

# names(reg_AD)


#Create Key

reg_AD$key_index <- reg_AD$cluster_key

# Cleaning the data

reg_AD[is.na(reg_AD$MD_DISCOUNT),"MD_DISCOUNT"] <- 0
reg_AD[is.na(reg_AD$Growth_perc),"Growth_perc"] <- 0
reg_AD[is.na(reg_AD$Maturity_perc),"Maturity_perc"] <- 0
reg_AD[is.na(reg_AD$decline_perc),"decline_perc"] <- 0

reg_AD[is.na(reg_AD$pos_disc),"pos_disc"] <- 0
reg_AD[is.na(reg_AD$first_disc),"first_disc"] <- 0
reg_AD[is.na(reg_AD$further_disc),"further_disc"] <- 0


# reg_AD[is.na(reg_AD$pos_perc),"pos_perc"] <- 0
# reg_AD[is.na(reg_AD$First_perc),"First_perc"] <- 0
# reg_AD[is.na(reg_AD$further_perc),"further_perc"] <- 0


reg_AD[is.na(reg_AD$Holiday),"Holiday"] <- 0
reg_AD[is.na(reg_AD$inventory_ratio_lag),"inventory_ratio_lag"] <- 0


# Modifying variables

reg_AD$log_Gross_sales_units = log(reg_AD$GROSS_SALES_UNITS+1)
reg_AD$month_flag = as.factor(reg_AD$month_flag)
#reg_AD$Disc_Type_Flag <- factor(reg_AD$Disc_Type_Flag, levels = c("None", "POS", "First", "Further"))
#MD_periods <- as.character(unique(reg_AD$Disc_Type_Flag))

reg_AD_copy <- reg_AD

rm("pe_output","resultdf","coefficients")
resultdf = NULL
coefficients = data.frame()
Sys.time()
i=2; j=1

# summary(reg_AD_copy)



# 
# for(j in 1:length(MD_periods))
# {
#   reg_AD <- reg_AD_copy[reg_AD_copy$Disc_Type_Flag==MD_periods[j],]
  distinct_key <- as.data.frame(as.character(unique(reg_AD$key_index)))
  colnames(distinct_key) <- ("key")
  
  for (i in 1:nrow(distinct_key))
  {
    tryCatch(
      {
        curr_key <- as.character(distinct_key$key[i])
        data = reg_AD[reg_AD$key_index == curr_key,]
        
        
        # indep_var <- c('MD_DISCOUNT','AGE_WEEKS','month_flag',"inventory_lag","Weeks_since_Launch","holiday_flag","High_Discount_Flag")
        
        indep_var <- c('MD_DISCOUNT','month_flag','AGE_WEEKS','pos_disc','first_disc','further_disc','Holiday')
        
        # indep_var <- c('MD_DISCOUNT','AGE_WEEKS','FISCAL_WEEK',"inventory_lag","decline_perc","Growth_perc","Maturity_perc")
        
        dep_var <- c('log_Gross_sales_units')
        model_equation <- reformulate(indep_var,dep_var)
        
        #Removing Log(sales) = Inf
        #data = data[!is.infinite(data$log_Gross_sales_units),]
        # sum(is.nan(reg_AD$INVENTORY))
        
        data$GROSS_SALES_UNITS<- ifelse(data$GROSS_SALES_UNITS>quantile(data$GROSS_SALES_UNITS,c(.99))
                                        ,quantile(data$GROSS_SALES_UNITS,c(.99))
                                        ,data$GROSS_SALES_UNITS)
        
      
        
        data <- data[order(data$Weeks_since_Launch),]
              row = as.integer(nrow(data)*.75)
        train = data [1:row,]
            test = data[(row+1):nrow(data),]
        
       
        PE_model<-lm(model_equation,na.action=na.pass,data=train)
        vfit1 <- data.frame(vif(PE_model))

#  Removing outliers based on Cooks distance
        cooksd <- cooks.distance(PE_model)
        

        train <- train[!(row.names(train) %in% names(cooksd)[cooksd>4/(nrow(train)-length(indep_var)-1)]),]
        
        
        PE_model<-lm(model_equation,na.action=na.pass,data=train)
        vfit1 <- data.frame(vif(PE_model))
        
        
        vfit1 <- cbind(Variables=as.character(row.names(vfit1)),vfit1)
        row.names(vfit1) <- NULL
        colnames(vfit1) <- c("Variables","Vif_val")
        
        
        pe_output <- data.frame(summary(PE_model)$coefficients)
        x = data.frame(t(coef(PE_model)))
        x$key = curr_key
        x$i = i; 
        x$avg_sales<-mean(data$GROSS_SALES_UNITS)
        x$positive_sales<-nrow(data[data$GROSS_SALES_UNITS>0, ])
        x$correlation<-cor(data$log_Gross_sales_units,data$MD_DISCOUNT)
          
        
        coefficients <- rbind.fill(coefficients,x)
        
        pe_output = cbind(Variables = row.names(pe_output), pe_output)
        pe_output$key <- curr_key
        rownames(pe_output) = NULL
        pe_output$Adj_RSq = summary(PE_model)[[9]]
        pe_output$RSq = summary(PE_model)[[8]]
        # pe_output$Period = MD_periods[j];
       
       
        pe_output = merge(pe_output, vfit1, by.x = 'Variables', by.y = 'Variables', all.x = T)
        
        
        #Insample MAPE
        
        Predicted_Sales <- exp(predict(PE_model, train[,indep_var]))
        pe_output$Insample_MAPE = mean(abs(Predicted_Sales[train$GROSS_SALES_UNITS>10]-train[train$GROSS_SALES_UNITS>10,"GROSS_SALES_UNITS"]+1)/(train[train$GROSS_SALES_UNITS>10,"GROSS_SALES_UNITS"]))
        # names(reg_AD)
        
        #outsample MAPE
        
        predicted_sales_valid <- exp(predict(PE_model, test[,indep_var]))
        pe_output$Outsample_MAPE = mean(abs(predicted_sales_valid[test$GROSS_SALES_UNITS>10]-test[test$GROSS_SALES_UNITS>10,"GROSS_SALES_UNITS"]+1)/test[test$GROSS_SALES_UNITS>10,"GROSS_SALES_UNITS"])
        
        resultdf = rbind(resultdf, pe_output)
      }, error = function(e){cat("ERROR : ",conditionMessage(e), "\n")})
  }
  
#Saving Results
name1 <- paste("Coefficients","segment","M1_ffp_inter_4_depts_wsl.csv",sep = "_") 
name2 <- paste("Results","segment","M1_ffp_inter_4_depts_wsl.csv",sep = "_")
write.csv(coefficients,name1, row.names = FALSE)
write.csv(resultdf,name2, row.names = FALSE)


rm(list=ls())
