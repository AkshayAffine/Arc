install.packages("Hmisc")
install.packages("cluster")
install.packages("fpc")
install.packages("NbClust")
install.packages("dbscan")
install.packages("clValid")
install.packages("dplyr")
installed.packages("flexmix")

require(ggplot2)
require(RODBC)
library(RODBC)
library(fpc)
library(cluster)
library(Hmisc)
library(factoextra)
library(NbClust)
library(dplyr)
library(clValid)

## Getting data from the segmentatio AD
getwd()

setwd("C:\\Users\\Muppalla Manaswini\\Documents\\tpc\\0517")

set.seed(10)

segment <- read.csv("Sed_Ad_0517.csv",header = TRUE)

class(segment)
names(segment)

## Winsorising data to remove outliers

# winsorising function
winsorize <- function (x, fraction=.01)
{
  if(length(fraction) != 1 || fraction < 0 ||
     fraction > 0.5) {
    stop("bad value for 'fraction'")
  }
  lim <- quantile(x, probs=c(fraction, 1-fraction))
  x[ x < lim[1] ] <- lim[1]
  x[ x > lim[2] ] <- lim[2]
  x
}

## Clustering Loop

cluster_wss_df <- NULL
cluster_final<- NULL
cluster_final<-data.frame(cluster_final)

for(i in 1:520)
{
  segment1 <- segment[segment$Rank == i,]
  if(nrow(segment1)<20)
  {
    #k <- 1
    next()
  }
  segment2 <- segment1[,c(4:5)]
  segment2$SALES <- winsorize(segment2$SALES)
  segment2$price <- winsorize(segment2$price)
  segment2[,c(1:2)] <- scale(segment2[,c(1:2)])
  unique_cnt <- as.numeric(apply(segment2,2,function(x) length(unique(x))))
  segment2 <- data.frame(segment2[,which(unique_cnt>1)])
  
  ## Determing and plotting elbow curve
  
  wss <- (nrow(segment2)-1)*sum(apply(segment2,2,var))
  for (j in 2:10) {  wss[j] <- sum(kmeans(segment2,centers=j,iter.max = 500, nstart = 20
                                          ,algorithm = c("MacQueen"))$withinss)}
  
  wss_df<-data.frame(wss)

  wss_df$cat_key <- as.character(unique(segment1$Cat_key))
   
  cluster_wss_df <- rbind(cluster_wss_df,wss_df)
  
  ## Performing optimum clustering algorithm based on sil value
  
  if (ncol(segment2)>1)
  {
  cl_kmeans <- kmeans(segment2,centers=3,
                      iter.max = 500, nstart = 20,
                      algorithm = c("MacQueen"))
  
  
  cl_pam <- pam(segment2, 3, diss = FALSE, metric = "euclidean", stand = TRUE)
  
  }
  
  
  if (ncol(segment2)<2)
  {
    cl_kmeans <- kmeans(segment2,centers=2,
                        iter.max = 500, nstart = 20,
                        algorithm = c("MacQueen"))
    
    
    cl_pam <- pam(segment2, 2, diss = FALSE, metric = "euclidean", stand = TRUE)
    
  }
  
  # Selecting best sil value
  
  sil_kmeans <- silhouette(cl_kmeans$cluster, dist(segment2))
  sil_kmeans_avg = mean(sil_kmeans[,3])
  sil_pam <- silhouette(cl_pam$cluster, dist(segment2))
  sil_pam_avg = mean(sil_pam[,3])
  # Selecting the best clustering algorithm
  
  cluster_final_interim = data.frame()
  
  if(sil_kmeans_avg>sil_pam_avg)
  {
    cluster_number<-cl_kmeans$cluster
    silhouette_width<-sil_kmeans[,3]
    cluster_final_interim = cbind(segment1,cluster_number,silhouette_width)
    cluster_final_interim$type = "k-means"
  }
  if (sil_kmeans_avg<=sil_pam_avg)
  {  
    cluster_number<-cl_pam$cluster
    silhouette_width<-sil_pam[,3]
    cluster_final_interim = cbind(segment1,cluster_number,silhouette_width)
    cluster_final_interim$type = "pam"
  }
  
  # Obtaining final file
  
  
   cluster_final <- rbind(cluster_final_interim,cluster_final)
  
  
  
}
# Saving results to the final file


setwd("C:\\Users\\Muppalla Manaswini\\Documents\\tpc\\0518")
write.csv(cluster_final,"cluster_final_0518.csv")

write.csv(cluster_wss_df,"cluster_final__wss_0518.csv")

i

------------------------------
  
  
  # Validation summary for top prority departments
  
  valid_summary <- clValid(segment2,2:6, clMethods=c("hierarchical","kmeans","pam"),validation="internal",maxitems=nrow(segment2))

#Plotting Clustering and Sil plots

get <- as.character(cluster_final$`cl$cluster`)

plot1[[i]] <- ggplot(cluster_final, aes(price,SALES, color = get, shape = get)) + geom_point(alpha = 0.4, size = 3.5) + ggtitle(label = cluster_final$Cat_key)

pdf(paste0("cluster_plotnew.pdf"), width=16, height = 4.5)
bquiet = lapply(plot1,print)
dev.off()