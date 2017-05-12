install.packages("Hmisc")
install.packages("cluster")
install.packages("fpc")
install.packages("NbClust")
install.packages("dbscan")

require(ggplot2)
require(RODBC)
library(RODBC)
library(fpc)
library(cluster)
library(Hmisc)
library(factoextra)
library(NbClust)
library(dplyr)

getwd()

setwd("D:/03 Projects 16-17/TPC_Arcadia/segmentation")

segment <- read.csv("segmentation_ad_1.csv",header = TRUE)

class(segment)
names(segment)
#--------------------------------------------------------------------------------------
#                      CLUSTERING LOOP
#--------------------------------------------------------------------------------------
cluster_final <- NULL
plot1<- list()
for(i in 1:520)
{
segment1 <- segment[segment$Rank == i,]
if(nrow(segment1)<20)
{
  #k <- 1
  next()
}
segment2 <- segment1[,c(4:6)]
segment2[,c(1:3)] <- scale(segment2[,c(1:3)])
unique_cnt <- as.numeric(apply(segment2,2,function(x) length(unique(x))))
segment2 <- segment2[,which(unique_cnt>1)]


#----------------------------------------------------------------------------------------
#                        Elbow Curve
#----------------------------------------------------------------------------------------

wss <- (nrow(segment2)-1)*sum(apply(segment2,2,var))
for (j in 2:10) {  wss[j] <- sum(kmeans(segment2,centers=j,iter.max = 500, nstart = 20
                                     ,algorithm = c("MacQueen"))$withinss)}

mypath <- file.path("D:\\03 Projects 16-17\\TPC_Arcadia\\Segmentation\\Results",paste("plot",i,".jpg",sep = ""))
jpeg(file=mypath)
plot(1:10, wss, type="b", xlab="Number of Clusters",ylab="WSS")
dev.off()
#----------------------------------------------------------------------------------
#                         Clustering 
#---------------------------------------------------------------------------------- 

cl <- kmeans(segment2,centers=4,
               iter.max = 500, nstart = 20,
               algorithm = c("MacQueen"))

#plot(segment[c("osp","sales_per_week")], col= cl$cluster)

#plotcluster(segment2,cl$cluster)

cluster_final_interim <- cbind(segment1,cl$cluster)

cluster_final <- rbind(cluster_final_interim,cluster_final)

get <- as.character(cluster_final$`cl$cluster`)

plot1[[i]] <- ggplot(cluster_final, aes(price,SALES, color = get, shape = get)) + geom_point(alpha = 0.4, size = 3.5) + ggtitle(label = cluster_final$Cat_key)

}

write.csv(cluster_final,"cluster_test.csv")

pdf(paste0("cluster_plotnew.pdf"), width=16, height = 4.5)
bquiet = lapply(plot1,print)
dev.off()
----------------------------------------------------------------------------
                    ### Validation ###
sil <- silhouette(cl$cluster, dist(segment2))
head(sil[, 1:3], 10)
plot(sil, main ="Silhouette plot - K-means",border = NA,col = c("blue","red","purple"))

# Compute pairwise-distance matrices
dd <- dist(segment2, method ="euclidean")
# Statistics for k-means clustering
km_stats <- cluster.stats(dd,  cl$cluster)
# (k-means) within clusters sum of squares
km_stats$within.cluster.ss

km_stats$clus.avg.silwidths

km_stats

