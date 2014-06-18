#############
# UCSC X IDTA Project
#june 2014
#Data Cleaning
#############

setwd("~/projet IDTA")
rm(list=ls())

#######modif par rapport a essai 3, vire IMO number renomme data source et shipYear
#######modif par rapport a Rmd, fat et injur modifies

#######
#Ship positions
#######

##### Loading

shipPos<-list()
i<-1
fileExtension<-c("A", "E", "O","S","Y","I")

load3<-function(file) {
  tempFile<-read.table(file, sep="\t", quote="",fill=T, header=T, stringsAsFactors=F)
  tempFile<-tempFile[-which(tempFile$position==""),-c(4,5)]
  return(tempFile)
}

for (letter in fileExtension) {
  myfile<-paste0("ship",letter)
  myzip<-paste0(myfile,".zip")
  mytxt<-paste0(myfile,".txt")
  shipPos[[i]]<-load3(unz(myzip, mytxt))
  i<-i+1
}
AA<-do.call(rbind, shipPos)
AA2<-unique(AA) #184 000 unique positions, a dataframe

#### Cleaning

latlg<-do.call(rbind,strsplit(AA2$position, ", "))

f<-function(x) gsub("'","",x)
latlg2<-apply(latlg,c(1,2),FUN=f) 

f2<-function(x) strsplit(x,"[ \\°]")
library("plyr")
lat<-ldply(sapply(latlg2[,1],FUN=f2))
lg<-ldply(sapply(latlg2[,2],FUN=f2))
lat<-lat[,-1]
lg<-lg[,-1]

convert<-function(x) {
  y<-as.numeric(x[,2])+as.numeric(x[,3])/60
  y<-ifelse ((x[,1]=="S")|(x[,1]=="W"), -y,y)
}

L<-convert(lat)
LL<-convert(lg)
position<-data.frame("lat"=L,"long"=LL)



##############
# IMO accidents
##############

#### Loading

### data was downloaded as pdf 
### it was then transformed into a csv file in python and read here

shipAcc<-list()
i<-1

fileExtension<-c("1998", "1999", "2000","2001","2002","2003")
cC<-c(NA, "character","NULL",rep("character",6),rep("NULL",2), "character", "NULL", 
      "character", "numeric", "character", "NULL")

for (letter in fileExtension) {
  myfile<-paste0("casualty",letter,"clean.csv")
  shipAcc[[i]]<-read.csv(myfile, stringsAsFactors=F, colClasses=cC, header=F)
  i<-i+1
}
casualty<-do.call(rbind, shipAcc)
names(casualty)<-c("dataSource", "flagState", "date", "casLife",
                   "lat", "long", "fatalities", "injuries", "consequence", "shipType", "DOB", "category")

#### Cleaning, in feature order

#dataSource: source of data. nothing to do

#flagState: flag State
cleanflag<-function(x) {
  x<-toupper(x)
  x[grepl("^CHINA", x)]<-"CHINA"
  x[grepl("^MARSHALL", x)]<-"MARSHALL ISLANDS"
  x<-gsub("KINGDON","KINGDOM",x)
  x<-gsub("S REP$"," REPUBLIC OF",x)
  x<-gsub(" BARGUDA", " BARBUDA",x)
  x<-gsub("VIET NAM","VIETNAM", x)
  x<-gsub("&","AND", x)
  x<-gsub("NETHERLANDS,","NETHERLANDS", x)
  return(x)
}

casualty$flagState<-cleanflag(casualty$flagState)


#date
library(lubridate)
dateclean<-function(x) {
  temp<-dmy(x)
  f3<-function(x) ifelse(x<2000, x+1900, x)
  year(temp)<-sapply(year(temp),f3)
  return(temp)
}
casualty$date<-dateclean(casualty$date)


#casLife (was someone injured or killed)
temp1<-gsub(" \\(.*\\)","",casualty$casLife)
temp1<-gsub("Casualty","Serious casualty", temp1)
#je ne distingue pas ou a eu lieu le drame, c'est l'accident qui compte
#reste un Casualty tout seul
casualty$casLife<-as.factor(temp1)


#lat and long: latitude and longitude
fmin<-function(x, pattern) {
  y<-ifelse(grepl(pattern,x),regmatches(x,regexec(pattern,x)), "0")
}
library(plyr)

convert2<-function(x) {
  l1<-do.call(rbind,strsplit(x,"o"))
  l2<-ldply(sapply(l1[,2], fmin, "^[0-9]+"))[,2] #I need only the values, not any name
  l3<-ldply(sapply(l1[,2], fmin, "\\.[0-9]+"))[,2]
  l4<-ldply(sapply(l1[,2], fmin, "[A-Z]"))[,2]
  l5<-as.numeric(l1[,1])+as.numeric(l2)/60+as.numeric(l3)
  l5<-ifelse ((l4=="S")|(l4=="W"), -l5,l5)
  return(l5)
}

casualty$lat<-convert2(casualty$lat)
casualty$long<-convert2(casualty$long)


#fatalities and injuries
casualty$fatalities<-as.numeric(casualty$fatalities)
casualty$injuries<-as.numeric(casualty$injuries)


#consequence : a consequence of the accident

cleantype<-function(x) {
  bkdnwithshore<-grepl("^B(.*)", x) & !grepl("^B(.*)g", x)
  x[bkdnwithshore]<-"Breakdown with shore assistance"
  x[grepl("^C(.*)", x)]<-"Constructive total loss"
  x<-gsub(" \\(.*\\)","",x)
  x[grepl("[Hh]ull", x)]<-"Structural damage"
  x[grepl("Tot(.*)lif(.*)*",x)]<-"Total loss and loss of life"
  x[grepl("Tot(.*)shi(.*)*",x)]<-"Total loss"
  return(x)
}

casualty$consequence<-cleantype(casualty$consequence)

#shipType: type of ship

cleanship<-function(x) {
  x<-toupper(x)
  x[grepl("BA(.*)",x)]<-"BARGE"
  x[grepl("BULK",x)]<-"BULK CARRIER"
  x[grepl("FISH",x)]<-"FISH RELATED SHIP"
  x[grepl("GAS ",x)]<-"GAS CARRIER"
  x[grepl("ICE(.*) ",x)]<-"ICEBREAKER"
  x[grepl("^RO(.*)",x)]<-"RO-RO CARGO SHIP"
  x[grepl("^TA(.*) ",x)]<-"TANKER"
  x[grepl("TUG",x)]<-"TUG"
  x[grepl("^VEH(.*)",x)]<-"VEHICLES CARRIER"
  return(x)
}

casualty$shipType<-cleanship(casualty$shipType)

#DOB: year of construction, nothing


#category: category of the accident

cleancat<-function(x){
  x[grepl("^Cap(.*)",x)]<-"Capsize"
  x[grepl("Fail(.*)",x)]<-"Hull failure"
  x[grepl("Fire and explosion",x)]<-"Fire/Explosion"
  grounding<-grepl("Groun(.*)",x) | grepl("Stra(.*)",x)
  x[grounding]<-"Grounding"
  x[grepl("Other(/|$)",x)]<-"Unknown"
  x[grepl("Work",x)]<-"Work-related accident"
  x[grepl("Fall",x)]<-"Fall overboard"
  return(x)
}

casualty$category<-cleancat(casualty$category)

rm(AA,AA2,lat,latlg,latlg2,lg, L,LL,cC,fileExtension,i,letter,myfile,mytxt,myzip,temp1)













