install.packages("Hmisc")
install.packages("cluster")
install.packages("fpc")
install.packages("NbClust")
install.packages("dbscan")
install.packages("clValid")

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

setwd("D:/03 Projects 16-17/TPC_Arcadia/segmentation")

set.seed(10)

segment <- read.csv("segmentation_ad_1.csv",header = TRUE)

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
segment2 <- segment2[,which(unique_cnt>1)]

## Determing and plotting elbow curve

wss <- (nrow(segment2)-1)*sum(apply(segment2,2,var))
for (j in 2:10) {  wss[j] <- sum(kmeans(segment2,centers=j,iter.max = 500, nstart = 20
                                     ,algorithm = c("MacQueen"))$withinss)}

## Performing optimum clustering algorithm based on sil value


cl_kmeans <- kmeans(segment2,centers=3,
               iter.max = 500, nstart = 20,
               algorithm = c("MacQueen"))


cl_pam <- pam(segment2, 3, diss = FALSE, metric = "euclidean", stand = TRUE)

# Selecting best sil value

sil_kmeans <- silhouette(cl_kmeans$cluster, dist(segment2))
sil_kmeans_avg = mean(sil_kmeans[,3])
sil_pam <- silhouette(cl_pam$cluster, dist(segment2))
sil_pam_avg = mean(sil_pam[,3])
# Selecting the best clustering algorithm

cluster_final_interim = data.frame()

if(sil_kmeans_avg>sil_pam_avg)
  {
    cluster_final_interim = cbind(segment1,cl_kmeans$cluster)
  }
if (sil_kmeans_avg<=sil_pam_avg)
  {  
    cluster_final_interim = cbind(segment1,cl_pam$cluster)
}

# Obtaining final file

if(exists("cluster_final")==TRUE){cluster_final <- rbind(cluster_final_interim,cluster_final)}
if(exists("cluster_final")==FALSE){cluster_final <- cluster_final_interim}

}
# Saving results to the final file

write.csv(cluster_final,"cluster_final_created.csv")

------------------------------

    
# Validation summary for top prority departments
  
valid_summary <- clValid(segment2,2:6, clMethods=c("hierarchical","kmeans","pam"),validation="internal",maxitems=nrow(segment2))

#Plotting Clustering and Sil plots

get <- as.character(cluster_final$`cl$cluster`)

plot1[[i]] <- ggplot(cluster_final, aes(price,SALES, color = get, shape = get)) + geom_point(alpha = 0.4, size = 3.5) + ggtitle(label = cluster_final$Cat_key)

pdf(paste0("cluster_plotnew.pdf"), width=16, height = 4.5)
bquiet = lapply(plot1,print)
dev.off()
