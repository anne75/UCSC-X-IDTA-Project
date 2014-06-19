####################
#This are all the commands I used in my analysis
# UCSC X IDTA Project
#june 2014
###################

setwd("~/projet IDTA")
rm(list=ls())
library("ggplot2")
library("ggmap")
library("mapdata")
library("lubridate")
library("plyr") #always put before following
library("dplyr")

###################################################################################
#Cleaning

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

#data source

#flagState
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


#lat and long
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


#consequence
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

#shipType
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

#shipYear 
#nothing

#category

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



#####################################################
#Geographical Analysis


world_map <- borders("worldHires", colour="#99FF99" ,fill="#99FF99") # create a layer of borders
mp <- ggplot(position, aes(x=long, y=lat)) + world_map 
mp<-mp + stat_density2d(aes(fill = ..level..), geom="polygon") + 
  scale_fill_gradient(low="#9999CC", high="#663399",name ="ship density") +
  geom_point(data= casualty, aes(x=long, y=lat, color=as.factor(casLife)), size=1) +
  scale_color_manual(values=c("#FF9900","#330000")) + 
  labs( x="longitude", y="latitude", color="casualty")
mp
range(position$lat)
range(position$long)


# Europe plot

fzone<-function(df,lat1,lat2,long1,long2=-long1) {
  cond<-with(df,(lat>lat1 & lat <lat2)&(long>long1 & long<long2))
  df2<-df[with(df,cond),]
  return(df2)
}
eur_pos<-fzone(position,47,58,-15,15)
eur_cas<-fzone(casualty,47,58,-15,15)

mp_eur <- ggplot(eur_pos, aes(x=long, y=lat)) + world_map + coord_cartesian(
  xlim=c(-15,15),ylim=c(47,58)) 
mp_eur + geom_point(color="#9999CC",size=1.7) + 
  geom_point(data= eur_cas, aes(x=long, y=lat, color=as.factor(casLife)), size=1.3) +
  scale_color_manual(values=c("#FF9900","#330000")) + 
  labs( x="longitude", y="latitude", color="casualty")

#China sea
asi_cas<-fzone(casualty,17,38,110,139)

nrow(eur_cas)
nrow(asi_cas)
round(2014-mean(eur_cas$DOB[eur_cas$DOB>=1850 & eur_cas$DOB<=2020], na.rm=T))
round(2014-mean(asi_cas$DOB[asi_cas$DOB>=1850 & asi_cas$DOB<=2020], na.rm=T))

ggplot()+ 
  scale_fill_manual(values=c("#FF000033","#0000FF33"), name="Area",labels=c("China Coast","Europe")) +
  geom_bar(data=eur_cas, aes(x=consequence, fill="Europe"),stat="bin") + #pour destack ,position="dodge"
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) +
  labs(x="type of casualty") +
  geom_bar(data=asi_cas,aes(x=consequence, fill="China Coast"),stat="bin")

#Heatmap
position$latCut<-cut(position$lat,breaks = seq(-90,90,length.out=11))
position$longCut<-cut(position$long,breaks = seq(-180,180,length.out=21))
poscut<-position%.%group_by(latCut, longCut)%.%summarise(position=n())

casualty$latCut<-cut(casualty$lat,breaks = seq(-90,90,length.out=11))
casualty$longCut<-cut(casualty$long,breaks = seq(-180,180,length.out=21))
cascut<-casualty%.%group_by(latCut, longCut)%.%summarise(casualty=n())

heat<-merge(poscut,cascut)
heat$density<-heat$casualty/heat$position

ggplot(data=heat, aes(x=longCut, y=latCut, fill=density))+geom_tile() +
  scale_fill_gradient(low="#9999CC", high="#663399",name ="density") +
  labs(x="longitudinal cuts", y="latitude cuts", title="Casualties Heatmap")+
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))

#Africa corn
rs_cas<-casualty[casualty$latCut=="(0,18]" & casualty$longCut=="(36,54]",]
rs_cas%.%group_by(consequence)%.%summarise(count=n())%.%arrange(desc(count))


### 3. Casualty Factors

#casLife

ser.table<-table(casualty$casLife)
ser.df<-data.frame(ser.table,"Percentage"=round(ser.table/sum(ser.table)*100,2))[,-3]
names(ser.df)<-c("seriousness","count","percentage")
ser.df

#flagState
length(unique(casualty$flagState))
flag.table<-sort(table(casualty$flagState), decreasing=T)
flag.freq<-data.frame("casualtyPercentage"=round(flag.table/sum(flag.table)*100,2))
head(flag.freq,10)

cia.ship<-read.table("../ciaship.txt", sep="\t", stringsAsFactors=F)
cia.ship<-cia.ship[,-1]
names(cia.ship)<-c("flagState", "merchantMarine")
cia.ship$flagState<-toupper(cia.ship$flagState)
cia.ship$merchantMarine<-as.numeric(gsub(",","",cia.ship$merchantMarine))
cia.ship$fleetPercentage<-round(cia.ship$merchantMarine/sum(cia.ship$merchantMarine)*100,2)
length(unique(cia.ship$flagState))
head(cia.ship[,c(1,3)],10)

#Date
casualty%.%group_by("year"=year(date))%.%summarise(nb=n())

#fatalities and injuries

casualty%.%group_by("year"=year(date))%.%summarise(nbFatlities=sum(fatalities, na.rm=T),
                                                   nbInjured=sum(injuries, na.rm=T))

casualty[casualty$fatalities>0 &!is.na(casualty$fatalities),]%.%group_by("year"=year(
  date))%.%summarise(nb=n(),nbFatlities=sum(fatalities))

casualty[which.max(casualty$fatalities),2:12]

#shipType
ship.table<-sort(table(casualty$shipType), decreasing=T)
ship.freq<-data.frame("casualtyPercentage"=round(ship.table/sum(ship.table)*100,2))
head(ship.freq,10)

world.fleet<-read.table("../worldfleet2005.txt", sep=";",stringsAsFactors=F, header=T,colClasses=
                          c("character","numeric","NULL"))
world.fleet$percentage<-round(world.fleet$Total/sum(world.fleet$Total)*100,2)
world.fleet[order(world.fleet$percentage, decreasing=T),c(1,3)]

head(casualty[casualty$shipType=="GENERAL CARGO SHIP",]%.%group_by(category)%.%summarise(
  count=n())%.%arrange(desc(count)),3)
head(casualty[casualty$shipType=="GENERAL CARGO SHIP",]%.%group_by(consequence=consequence)%.%summarise(
  count=n())%.%arrange(desc(count)),3)
casualty[casualty$shipType=="GENERAL CARGO SHIP",]%.%group_by(casLife)%.%summarise(
  count=n())
head(casualty[casualty$shipType!="GENERAL CARGO SHIP",]%.%group_by(category)%.%summarise(
  count=n())%.%arrange(desc(count)),5)
head(casualty[casualty$shipType!="GENERAL CARGO SHIP",]%.%group_by(consequence)%.%summarise(
  count=n())%.%arrange(desc(count)),5)
casualty[casualty$shipType!="GENERAL CARGO SHIP",]%.%group_by(casLife)%.%summarise(
  count=n())


head(casualty[casualty$shipType=="TUG",]%.%group_by(category)%.%summarise(
  count=n())%.%arrange(desc(count)),3)
head(casualty[casualty$shipType=="TUG",]%.%group_by(consequence)%.%summarise(
  count=n())%.%arrange(desc(count)),3)
casualty[casualty$shipType=="TUG",]%.%group_by(casLife)%.%summarise(
  count=n())


head(casualty[casualty$shipType=="RO-RO CARGO SHIP",]%.%group_by(category)%.%summarise(
  count=n())%.%arrange(desc(count)),3)
head(casualty[casualty$shipType=="RO-RO CARGO SHIP",]%.%group_by(consequence=consequence)%.%summarise(
  count=n())%.%arrange(desc(count)),3)
casualty[casualty$shipType=="RO-RO CARGO SHIP",]%.%group_by(casLife)%.%summarise(
  count=n())


table(casualty$casLife[casualty$shipType=="RO-RO CARGO SHIP"])

#DOB
summary(casualty$DOB[casualty$DOB>=1800 & casualty$DOB<2010])

#consequence and category
summary(table(casualty$consequence, casualty$category))$statistic
summary(table(casualty$consequence, casualty$category))$p.value

ggplot(casualty, aes(x=casLife, fill=category))+geom_bar(stat="bin") + #pour destack ,position="dodge"
theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1),
      strip.text.x = element_text(angle = 90)) +
labs(x="seriousness of accident", fill="category") +
facet_grid(.~consequence, scales="free", space="free")

