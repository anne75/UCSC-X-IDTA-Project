*Data Cleaning*
========================================================

This the script for the data cleaning step of my analysis.




1. Ship positions
-----------------
I combine 6 data sets to get a simple dataframe : position. Details below.


```r
##### Loading
shipPos <- list()
i <- 1
fileExtension <- c("A", "E", "O", "S", "Y", "I")

load3 <- function(file) {
    tempFile <- read.table(file, sep = "\t", quote = "", fill = T, header = T, 
        stringsAsFactors = F)
    tempFile <- tempFile[-which(tempFile$position == ""), -c(4, 5)]
    return(tempFile)
}

for (letter in fileExtension) {
    myfile <- paste0("ship", letter)
    myzip <- paste0("../", myfile, ".zip")
    mytxt <- paste0(myfile, ".txt")
    shipPos[[i]] <- load3(unz(myzip, mytxt))
    i <- i + 1
}
AA <- do.call(rbind, shipPos)
AA2 <- unique(AA)  # a data frame of 184 000 unique positions

#### Cleaning : transform latitude and longitude into numbers and decimal
#### degree units

latlg <- do.call(rbind, strsplit(AA2$position, ", "))

f <- function(x) gsub("'", "", x)
latlg2 <- apply(latlg, c(1, 2), FUN = f)

f2 <- function(x) strsplit(x, "[ \\°]")
library("plyr")
lat <- ldply(sapply(latlg2[, 1], FUN = f2))
lg <- ldply(sapply(latlg2[, 2], FUN = f2))
lat <- lat[, -1]
lg <- lg[, -1]

convert <- function(x) {
    y <- as.numeric(x[, 2]) + as.numeric(x[, 3])/60
    y <- ifelse((x[, 1] == "S") | (x[, 1] == "W"), -y, y)
}

L <- convert(lat)
LL <- convert(lg)
position <- data.frame(lat = L, long = LL)

str(position)
```

```
## 'data.frame':	183931 obs. of  2 variables:
##  $ lat : num  51.33 23.1 40.08 51.95 1.18 ...
##  $ long: num  3.82 113.45 120.03 5.37 103.87 ...
```

```r

head(position, 3)
```

```
##     lat    long
## 1 51.33   3.817
## 2 23.10 113.450
## 3 40.08 120.033
```

```r

tail(position, 3)
```

```
##          lat   long
## 183929 29.62 -94.95
## 183930 25.45  52.35
## 183931 18.13 -63.43
```


2. Casualties
---------------

I combine 6 datasets in csv format (the transfomation from pdf to txt was automated with ocular and the txt to csv was done in python).

  * pdf to txt

In the txt format, the data concerning 1 accident are given on 3 rows with different fixed width format. I reshaped it on 1 row in the csv format.
I select only the accidents were the position is given ( with latitude and longitude).

```
This is the code in python for one document, the code had to be tuned to each document

import re
import os
import csv
try:
    from itertools import izip_longest  # added in Py 2.6
except ImportError:
    from itertools import zip_longest as izip_longest  # name change in Py 3.x
try:
    from itertools import accumulate  # added in Py 3.2
except ImportError:
    def accumulate(iterable):
        'Return running totals (simplified version).'
        total = next(iterable)
        yield total
        for value in iterable:
            total += value
            yield total

##### LOGISTIC
os.chdir('/home/anne/projet IDTA')

filename = 'casualty2000.txt'

new_file = []

pattern1  = '^([A-Z]+[a-z]*){2,6}|Other' #identify the first line
pattern4 = "[0-9]+o*[0-9]*\'*[\\.]*[0-9]*[A-Z]" #latitude and longitude pattern

with open(filename, 'r') as f:
   lines = f.readlines()

##### FUN DEF
def make_parser(fieldwidths):
    cuts = tuple(cut for cut in accumulate(abs(fw) for fw in fieldwidths))
    pads = tuple(fw < 0 for fw in fieldwidths) # bool values for padding fields
    flds = tuple(izip_longest(pads, (0,)+cuts, cuts))[:-1]  # ignore final one
    parse = lambda line: tuple(line[i:j] for pad, i, j in flds if not pad)
    # optional informational function attributes
    parse.size = sum(abs(fw) for fw in fieldwidths)
    parse.fmtstring = ' '.join('{}{}'.format(abs(fw), 'x' if fw < 0 else 's')
                                                for fw in fieldwidths)
    return parse

def parse_line(line,*args):  #parse the first line
    parse = make_parser(args)
    return parse(line)

def parse_l23(line):         #parse the 2nd and 3rd line
    if len(line)<190 :
        fields = (-7, 60, 8,-9,(len(line)-153),40) #143
    else :
        fields = (-7, 60, 8,-10,(len(line)-163),40)
    fieldsL2 = parse_line(line,*fields)
    return fieldsL2

# Iterate each line
for i in xrange(len(lines)):

    # Regex applied to each line 
    match = re.search(pattern1, lines[i]) # je cherche la classe
    if match:
        latLong=re.findall(pattern4, lines[i]) # je cherche s'il y a la position
        if len(latLong)>1:
            if len(lines[i])<190 :
                fields = (-7, 60, 8,10,(len(lines[i])-155),27,27,10,10)##143
            else :
                fields = (-7, 60, 8,11,(len(lines[i])-163),27,27,15,15)
            fieldsL1 = parse_line(lines[i],*fields)    
            fieldsL1 = (match.group(),)+fieldsL1
            
            fieldsL2 = parse_l23(lines[i+1])
            
            fieldsL3 = parse_l23(lines[i+2])
            
            new_line=map(lambda x: x.strip(), list(fieldsL1+fieldsL2+fieldsL3))
            new_file.append(new_line)

#export
with open('casualty2000clean.csv', 'w') as f:
     # go to start of file
     f.seek(0)
     writer=csv.writer(f)
     # actually write the lines
     writer.writerows(new_file)
```

  * csv loading and cleaning

My final output is the dataframe casualty, detailed below.


```r
shipAcc <- list()
i <- 1

fileExtension <- c("1998", "1999", "2000", "2001", "2002", "2003")
cC <- c(NA, "character", "NULL", rep("character", 6), rep("NULL", 2), "character", 
    "NULL", "character", "numeric", "character", "NULL")

for (letter in fileExtension) {
    myfile <- paste0("../casualty", letter, "clean.csv")
    shipAcc[[i]] <- read.csv(myfile, stringsAsFactors = F, colClasses = cC, 
        header = F)
    i <- i + 1
}
casualty <- do.call(rbind, shipAcc)
names(casualty) <- c("dataSource", "flagState", "date", "casLife", "lat", "long", 
    "fatalities", "injuries", "consequence", "shipType", "DOB", "category")

#### Cleaning, in feature order

# dataSource: source of data. nothing to do

# flagState: flag State
cleanflag <- function(x) {
    x <- toupper(x)
    x[grepl("^CHINA", x)] <- "CHINA"
    x[grepl("^MARSHALL", x)] <- "MARSHALL ISLANDS"
    x <- gsub("KINGDON", "KINGDOM", x)
    x <- gsub("S REP$", " REPUBLIC OF", x)
    x <- gsub(" BARGUDA", " BARBUDA", x)
    x <- gsub("VIET NAM", "VIETNAM", x)
    x <- gsub("&", "AND", x)
    x <- gsub("NETHERLANDS,", "NETHERLANDS", x)
    return(x)
}

casualty$flagState <- cleanflag(casualty$flagState)


# date
library(lubridate)
dateclean <- function(x) {
    temp <- dmy(x)
    f3 <- function(x) ifelse(x < 2000, x + 1900, x)
    year(temp) <- sapply(year(temp), f3)
    return(temp)
}
casualty$date <- dateclean(casualty$date)


# casLife (was someone injured or killed)
temp1 <- gsub(" \\(.*\\)", "", casualty$casLife)
temp1 <- gsub("Casualty", "Serious casualty", temp1)

casualty$casLife <- as.factor(temp1)


# lat and long: latitude and longitude
fmin <- function(x, pattern) {
    y <- ifelse(grepl(pattern, x), regmatches(x, regexec(pattern, x)), "0")
}
library(plyr)

convert2 <- function(x) {
    l1 <- do.call(rbind, strsplit(x, "o"))
    l2 <- ldply(sapply(l1[, 2], fmin, "^[0-9]+"))[, 2]  #I need only the values, not any name
    l3 <- ldply(sapply(l1[, 2], fmin, "\\.[0-9]+"))[, 2]
    l4 <- ldply(sapply(l1[, 2], fmin, "[A-Z]"))[, 2]
    l5 <- as.numeric(l1[, 1]) + as.numeric(l2)/60 + as.numeric(l3)
    l5 <- ifelse((l4 == "S") | (l4 == "W"), -l5, l5)
    return(l5)
}

casualty$lat <- convert2(casualty$lat)
casualty$long <- convert2(casualty$long)


# fatalities and injuries
casualty$fatalities <- as.numeric(casualty$fatalities)
```

```
## Warning: NAs introduced by coercion
```

```r
casualty$injuries <- as.numeric(casualty$injuries)
```

```
## Warning: NAs introduced by coercion
```

```r


# consequence : a consequence of the accident

cleantype <- function(x) {
    bkdnwithshore <- grepl("^B(.*)", x) & !grepl("^B(.*)g", x)
    x[bkdnwithshore] <- "Breakdown with shore assistance"
    x[grepl("^C(.*)", x)] <- "Constructive total loss"
    x <- gsub(" \\(.*\\)", "", x)
    x[grepl("[Hh]ull", x)] <- "Structural damage"
    x[grepl("Tot(.*)lif(.*)*", x)] <- "Total loss and loss of life"
    x[grepl("Tot(.*)shi(.*)*", x)] <- "Total loss"
    return(x)
}

casualty$consequence <- cleantype(casualty$consequence)

# shipType: type of ship

cleanship <- function(x) {
    x <- toupper(x)
    x[grepl("BA(.*)", x)] <- "BARGE"
    x[grepl("BULK", x)] <- "BULK CARRIER"
    x[grepl("FISH", x)] <- "FISH RELATED SHIP"
    x[grepl("GAS ", x)] <- "GAS CARRIER"
    x[grepl("ICE(.*) ", x)] <- "ICEBREAKER"
    x[grepl("^RO(.*)", x)] <- "RO-RO CARGO SHIP"
    x[grepl("^TA(.*) ", x)] <- "TANKER"
    x[grepl("TUG", x)] <- "TUG"
    x[grepl("^VEH(.*)", x)] <- "VEHICLES CARRIER"
    return(x)
}

casualty$shipType <- cleanship(casualty$shipType)

# DOB: year of construction, nothing


# category: category of the accident

cleancat <- function(x) {
    x[grepl("^Cap(.*)", x)] <- "Capsize"
    x[grepl("Fail(.*)", x)] <- "Hull failure"
    x[grepl("Fire and explosion", x)] <- "Fire/Explosion"
    grounding <- grepl("Groun(.*)", x) | grepl("Stra(.*)", x)
    x[grounding] <- "Grounding"
    x[grepl("Other(/|$)", x)] <- "Unknown"
    x[grepl("Work", x)] <- "Work-related accident"
    x[grepl("Fall", x)] <- "Fall overboard"
    return(x)
}

casualty$category <- cleancat(casualty$category)

str(casualty)
```

```
## 'data.frame':	910 obs. of  12 variables:
##  $ dataSource : chr  "ILU" "SITREP" "SITREP" "LRS" ...
##  $ flagState  : chr  "ANTIGUA AND BARBUDA" "ANTIGUA AND BARBUDA" "AUSTRALIA" "AUSTRIA" ...
##  $ date       : POSIXct, format: "1998-06-27" "1998-04-13" ...
##  $ casLife    : Factor w/ 2 levels "Serious casualty",..: 1 1 1 2 1 1 1 2 1 1 ...
##  $ lat        : num  43.7 51 -65.5 35.1 50.3 ...
##  $ long       : num  -9.12 1.62 144.47 -9.28 -1.55 ...
##  $ fatalities : num  0 0 0 4 0 0 0 1 0 0 ...
##  $ injuries   : num  0 0 0 0 0 0 0 1 0 0 ...
##  $ consequence: chr  "Constructive total loss" "Breakdown with towage" "Breakdown with towage" "Total loss and loss of life" ...
##  $ shipType   : chr  "GENERAL CARGO SHIP" "GENERAL CARGO SHIP" "RESEARCH SHIP" "GENERAL CARGO SHIP" ...
##  $ DOB        : num  1989 1983 1990 1976 1973 ...
##  $ category   : chr  "Grounding" "Collision" "Fire/Explosion" "Hull failure" ...
```

```r

head(casualty, 3)
```

```
##   dataSource           flagState       date          casLife    lat
## 1        ILU ANTIGUA AND BARBUDA 1998-06-27 Serious casualty  43.70
## 2     SITREP ANTIGUA AND BARBUDA 1998-04-13 Serious casualty  50.97
## 3     SITREP           AUSTRALIA 1998-07-21 Serious casualty -65.48
##      long fatalities injuries             consequence           shipType
## 1  -9.117          0        0 Constructive total loss GENERAL CARGO SHIP
## 2   1.617          0        0   Breakdown with towage GENERAL CARGO SHIP
## 3 144.467          0        0   Breakdown with towage      RESEARCH SHIP
##    DOB       category
## 1 1989      Grounding
## 2 1983      Collision
## 3 1990 Fire/Explosion
```
