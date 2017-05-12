#RODBC Connection

library(RODBC)
channel <- odbcConnect(dsn='TPC_Arcadia', uid='sa', pwd='test@123')
PLC_AD <- sqlQuery(channel,"select * from PLC_AD_cat_level ")
colnames(PLC_AD)

j=1; er <- as.list(NULL)
cat_list <- unique(PLC_AD[,"cat_key"])
i=1
for(i in 1:length(cat_list))
{
cat <- PLC_AD[which(PLC_AD$cat_key==cat_list[i]),]
cat <- PLC_AD[which(PLC_AD$cat_key==1217),]
y_variable <- "CST"
x_variable <- "Age_in_weeks"
# 
# y_variable <- "Check_out_rate"
# x_variable <- "CST"


data <- cat
  y <- as.numeric(data[,y_variable])
  x <- as.numeric(data[,x_variable])
#   y <- y[1:length(y)-1]
#   x<- x[2:length(x)]
  # x2 <- x*x
#   x3 <- x2*x
#   x4 <- x3*x
tryCatch({
  
  # mod_reg <- lm(y~log(x))
  # mod_reg <- lm(y~x+x2+x3+x4)
  mod_reg <- nls(y ~ SSlogis(x, phi1, phi2, phi3))
  # summary(mod_reg)
  # coef(mod_reg)
  
  plot(x,y,col='deepskyblue4',main='Observed data')
  lines(x,predict(mod_reg),col='red')
  # plot(x[2:length(x)],slp,col='deepskyblue4',xlab='q',main='Observed data')
  
  # a <- coeff[1]
  # b1 <- coeff[2]
  # b2 <- coeff[3]
  # b3 <- ifelse(is.na(coeff[4]),0,coeff[4])
  x_new <- seq(0.00,max(x),by = max(x)/(length(y)-1))
  y_new <- predict(mod_reg)
  slp <- diff(y_new)/diff(x_new)
  plot(x[2:length(x)],slp,col='deepskyblue4',xlab='q',main='Observed data')
  x_new2 <- seq(0.00,max(x),by = max(x)/(length(slp)-1))
  slp2 <- diff(slp)/diff(x_new2)
  plot(x[3:length(x)],slp2,col='deepskyblue4',xlab='q',main='Observed data')

#   x_new3 <- seq(0.00,max(x),by = max(x)/(length(slp2)-1))
#   slp3 <- diff(slp2)/diff(x_new3)
#   plot(x[4:length(x)],slp3,col='deepskyblue4',xlab='q',main='Observed data')
#   
#   deriv <- function(m,n) diff(n) / diff(m)
#   middle_pts <- function(m) m[-1] - diff(m) / 2
#   second_d <- deriv(middle_pts(x_new), deriv(x_new, y_new))
#   
  # plot(x_new,y_new)
#   plot(middle_pts(middle_pts(x_new)), deriv(middle_pts(x_new), deriv(x_new, y_new)))
#   
  
#   infl1 <- max(which(slp2 == max(slp2[slp2<=-0.005])))
#   infl2 <- max(which(slp2 == max(slp2[slp2>-0.005 & slp2<=-0.0005])))

  infl1 <- min(which(slp2<=0))-1
  infl2 <- which(slp2==min(slp2[slp2<=0]))+1
  
  
  
  stage <- "M"
  stage <- ifelse(data[,x_variable] <= x[infl1], "G", stage)
  #stage <- ifelse(x <= x_new[infl1], "G", stage)
  stage <- ifelse(data[,x_variable] >= x[infl2], "D", stage)
  #stage <- ifelse(x >= x_new[infl2], "D", stage)
  # return(stage)
  color <- ifelse(stage=="G","green",ifelse(stage=="M","blue","red"))
  
  
  
  
  #Saving Plots
  mypath <- file.path("C:","Users","Sachin","Desktop","TPC Arcadia","Product Life Cycle Analysis","LogGrowthPlots",paste( cat_list[i], ".jpg", sep = ""))
  jpeg(filename=mypath)
  mytitle = paste("Catg. -", cat_list[i])
  plot(x,y,col=color,main=mytitle)
  lines(x,predict(mod_reg),col='red')
  dev.off()
  
  #Residuals
  mypath <- file.path("C:","Users","Sachin","Desktop","TPC Arcadia","Product Life Cycle Analysis","LogGrowthPlots",paste( cat_list[i], "_R.jpg", sep = ""))
  jpeg(file=mypath)
  mytitle = paste("Residual Catg. -", cat_list[i])
  plot(fitted(mod_reg),residuals(mod_reg), main = mytitle)
  dev.off()
  
# Collating in a dataset
  cur_cat_results <- data.frame(cat_list[i],coef(mod_reg)[1],coef(mod_reg)[2],coef(mod_reg)[3],infl1,infl2)
  row.names(cur_cat_results) <-  NULL
  colnames(cur_cat_results) <-  c("Cat_key","phi1","phi2","phi3","Infl1","Infl2")
  if(exists("cat_results") == TRUE){cat_results <- rbind(cat_results,cur_cat_results)}
  if(exists("cat_results") == FALSE){cat_results <- cur_cat_results}
   
  # rm(cat_results)
  
},error=function(e){er[j] <- cat_list[i]; j=j+1;})
}


sqlSave(channel, cat_results, tablename = "PLC_Cat_Results")
