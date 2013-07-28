#!/bin/bash

if [ ! -f "$1" ] ; then
	echo usage: $0 log-file
	exit 1
fi

grep ^real "$1"  | cut -f2 | \
	sed -e 's/s$//' -e 's/m/,/' -e 's/\./,/' > real
	#sed -e 's/s$//' -e 's/m/:/' -e 's/:\([0-9]\)\./:0\1./' -e 's/\..*$//' > real

R --vanilla <<EOF
x <- read.csv("real",header=F)
#plot(x)

t <- (x[,1]*60)+(x[,2])+(x[,3]/100)

# analyse (in reverse order)
hist(t, ylab="keys completed", xlab="seconds", main="Histogram of time taken")
stripchart(t,method="jitter",pch=1, xlab="seconds to complete", main="scatter plot of completion times")
plot(t)

summary(t)
t.test(t)
t
EOF

# I combined the "mangled" files by adding a ",1" to the row to signify it was
# from elspicyjack or ",0" to say that it was from the iMac:
#
#  cat real-spicy | sed -e 's/$/,1/' > realX
#  cat real-imac | sed -e 's/$/,0/' >> realX

# This I then put into R:
#
# t <- (x[,1]*60)+(x[,2])+(x[,3]/100)
# t2 <- x[,4]
# boxplot(t~t2,method="jitter",pch=1,horizontal=T)
# layout(matrix(c(1,2), 2, 1, byrow = TRUE))
# stripchart(t[t2==0],method="jitter",pch=1)
# stripchart(t[t2==1],method="jitter",pch=1)
# t.test(t~t2)
