#!/bin/sh
#### Clears the trace up to the simulation time limit
rm -v *.result
rm -v Trace_Cleaned.tr
rm -r Jitter/ 
rm -r Delay/ 
rm -r Forward/ 
rm -r Packet_Loss/
rm -r Throughput/
rm -r Energy/

for sim in $(seq 0 0); do 
echo "Cleanning Trace..."
cat TRACE_File.tr   | sed 's/\[//g' | sed 's/\]//g' | sed 's/\_//g' | sed 's/\:/ /g' \
| awk -F" " '{ {if($2 < 60.000000000) {print}}}' > Trace_Cleaned_Sujo.tr 
cat Trace_Cleaned_Sujo.tr | uniq > Trace_Cleaned.tr

egrep "^[sr].*AGT.*" Trace_Cleaned.tr > Trace_R_S.tr 
echo "Trace Clean and node's number updated..."
rm Trace_Cleaned_Sujo.tr

######Throughput Calculation ###### 
#Based in: http://ns2ultimate.tumblr.com/post/3442965938/post-processing-ns2-result-using-ns2-trace-ex1 (T. Issaraiyakul and E. Hossain)
echo "Extracting Throughput..."
mkdir -pv Throughput
for conta in $(seq 0 59);
do 
cat Trace_R_S.tr | awk -F " " 'BEGIN{ 
lineCount = 0;
totalBits = 0;
}
/^r/&&$4=="AGT"&&$24=="'$conta'"{
	if ($8==270) {
		totalBits += 8*($8-20);
   } else {
		totalBits += 8*$8;
	};
	if (lineCount==0) {
		timeBegin = $2;
		lineCount++;
	} else {
		timeEnd = $2;
	};
};
END{
duration = timeEnd-timeBegin;
if(timeEnd==0) {
	duration = (timeEnd-timeBegin)*-1;
} 	
Thoughput = totalBits/duration/1e3;
	printf("%3.5f",Thoughput);
};' > Throughput/Throughput_$conta.tr
done;
rm Throughput/mediaV.tr
for conta in $(seq 0 59);
do
##### Checks if you have any empty files and writes a value so that the average calculation is computed without errors.
if [ -s Throughput/Throughput_$conta.tr ]; then
awk -F" " '{print}' Throughput/Throughput_$conta.tr >> Throughput/mediaV.tr
fi
done;
#Average Throughput
cat Throughput/mediaV.tr | awk -F" " '{
Vetor_media[NR] = $0
} END {
	for(j = 1; j <= NR; j++){
		if(j in Vetor_media){	
			soma = soma + Vetor_media[j]	
		}
	}
	media = soma/NR
    printf("%3.5f",media)
}' > Throughput/Media_Throughput.tr
echo "End of Throughput Calculation..."

### Energy Consumption ###
echo "Extracting Energy..."
mkdir -pv Energy
egrep "^N.*" Trace_Cleaned.tr > Energy/Energia_total.e 
# The fields $5, $7 and $3 correspond respectively to: the node, the total energy and the current time within the simulation
cat Energy/Energia_total.e | awk -F" " '{print $5 " " $7 " " $3}' > Energy/Energia_total_col_nodo_energy.e
rm Energy/Energia_Final_Geral.e  
for conta in $(seq 0 59);
do
#The fields $3 and $2 are based on the file ''Energia_total_col_nodo_energy_unicos.e' and correspond to the simulation time and total energy 
cat Energy/Energia_total_col_nodo_energy.e  | awk -F" " '{if($1=="'$conta'") {print $3 " " $2}}' > Energy/Energia_total_$conta.e 
cat Energy/Energia_total_$conta.e | awk -F" " 'END { print (100.000000 - $2) }' > Energy/Energia_Final_$conta.e
cat  Energy/Energia_Final_$conta.e >> Energy/Energia_Final_Geral.e
done;
#####Global Average Energy Consumption
cat Energy/Energia_Final_Geral.e | awk -F" " '{
Vetor_media[NR] = $0
} END {
	for(m = 1; m <= NR; m++){
	soma = soma + Vetor_media[m]	
	}
	media = soma/NR
	printf("%3.5f",media)
}' > Energy/MediaGlobal_En.e
echo "End Energy Consumption Calculation..."

#Packet Loss Rate Calculation
echo "Extracting Packet Loss Rate..."
mkdir -pv Packet_Loss
egrep "^[sr].*AGT.*" Trace_Cleaned.tr > Trace_R_S.tr 
#Print only send (s) events
cat Trace_R_S.tr | awk -F " " '{   
	if($1 == "s" && $4 == "AGT"){
		{print}		
	}
 }' > Packet_Loss/S.tr
#Count just packets sended by application Layer
export s=$(awk -F" " 'END { print NR }' Packet_Loss/S.tr)
#Print only receive (s) events
cat Trace_R_S.tr | awk -F " " '{   
	if($1 == "r" && $4 == "AGT"){
		{print}		
	}
 }' > Packet_Loss/R.tr
#Count just packets received in application Layer
export r=$(awk -F" " 'END { print NR }' Packet_Loss/R.tr)
#Calculates the packet loss rate in units
awk -v S=$s -v R=$r -F " " 'BEGIN {
	PLR = S - R;
	{print PLR}
}' > Packet_Loss/PLR_U.p
#Calculates the packet loss rate as a percentage
awk -v S=$s -v R=$r -F " " 'BEGIN {
	PLR = S - R;
	{print (PLR/S)*100}
}' > Packet_Loss/PLR_R.p
#Record the number of packet generated by application layer
echo $s > Packet_Loss/packet_generated.p
#Record the number of packet received by application layer
echo $r > Packet_Loss/packet_received.p

#Write to a file dropped packets by selfishness.
cat Trace_Cleaned.tr | awk -F " " '{  
	if($5 == "SEL"){  
		{print}
	}		
 }' > Packet_Loss/Selfish_Drops.tr
rm Packet_Loss/Dropped_by_Selfish_Nodes.s
for No in $(seq 0 59);
do 
 cat Packet_Loss/Selfish_Drops.tr | awk -F" " '{
		if($3 == "'$No'"){  
		{print}
		}	
}' > Packet_Loss/Selfish_Drops_$No.tr
awk -F" " 'END { print NR }' Packet_Loss/Selfish_Drops_$No.tr >>  Packet_Loss/Dropped_by_Selfish_Nodes.s
done;	
echo "End Packet Loss Rate Calculation..."

###Routing Overhead Calculation.
echo "Extracting Routing Overhead Rate..."
mkdir -pv Overhead
rm Overhead/Overhead_by_no.tr 
cat Trace_Cleaned.tr | awk -F" " '{if($1=="s" && ($7=="OLSR" || $7=="AODV" || $7=="DSR" || $7=="message")){{print}}}' > Overhead/OVER.tr
awk -F" " 'END { print NR }' Overhead/OVER.tr > Overhead/Overhead.tr 
for conta in $(seq 0 59);
do
cat  Overhead/OVER.tr | awk -F" " '{
	if($3=="'$conta'")
	{print}
}' > Overhead/OVER_By_$conta.ov
#Check there is some empty file and writes a value for the average calculus is computed without errors.
if [ ! -s Overhead/OVER_By_$conta.ov ]; then
echo "Arquivo Overhead/OVER_By_$conta.ov is empty!"
echo "0" > Overhead/OVER_By_$conta.ov
else
echo "Arquivo Overhead/OVER_By_$conta.ov isn't empty!"
fi
awk -F" " 'END {if($1=="0") { print NR==0} else { print NR} }' Overhead/OVER_By_$conta.ov >> Overhead/Overhead_by_no.tr
done;
#Another form to calculate routing overhead.
#Calculates routing overhead dividing the byte number of routing overhead by the number of data bytes
export OH=$(cat Overhead/OVER.tr | awk -F " " 'BEGIN {OH = 0;} /^s/&&$4=="MAC"{OH=OH+$8}; END {printf("%f\n"), OH;}')
export DATA=$(cat Trace_Cleaned.tr | awk -F " " 'BEGIN {DATA = 0;} /^r/&&$4=="AGT"{DATA=DATA+$8}; END {printf("%f\n"), DATA;}')
echo $OH > Overhead/OH_Bytes.b
echo $DATA > Overhead/DATA_Bytes.b
awk -v overhead=$OH -v data=$DATA -F" " 'BEGIN { print (overhead/data)*100}' > Overhead/Overhead_R.tr
echo "End Routing Overhead Calculation!!!"

###FORWARD Rate Calculation.
echo "Extracting Forward Rate..."
mkdir -pv Forward
rm Forward/Forward_by_no.tr
# Create a file with all the Packets Forwarded
cat Trace_Cleaned.tr | egrep "^f.*" | awk -F" " '{if($7=="cbr" \
	|| $7=="tcp") {{print}}}'> Forward/FWD_ALL.tr
# Record the quantity of all packets forwarded	
awk -F" " 'END { print NR }' Forward/FWD_ALL.tr > Forward/Forward_ALL_Number.tr
# Record how much each node forward, all packets
for conta in $(seq 0 59); do
cat Forward/FWD_ALL.tr | awk -F" " '{
	if($3=="'$conta'") 
	{print}
}' > Forward/FWD_ALL_By_$conta.f
# Checks if there are any empty files and writes a value zero in them
if [ ! -s Forward/FWD_ALL_By_$conta.f ]; then
echo "File Forward/FWD_ALL_By_$conta.f is empty!"
echo "0" > Forward/FWD_ALL_By_$conta.f
else
echo "File Forward/FWD_ALL_By_$conta.f isn't empty!"
fi
awk -F" " 'END {if($1=="0") {print NR==0} else {print NR}}' \
Forward/FWD_ALL_By_$conta.f >> Forward/Forward_by_no.tr 
done;
# Create a file with all packets forwarded 
cat Forward/FWD_ALL.tr | awk -F" " '{print $3 " " $6 " " $24 " " $26}' > \
Forward/FWD_UNIQ.tr
# Create a file with Packet ID less repetition
cat Forward/FWD_UNIQ.tr | awk -F" " '{{print $2}}' | uniq -u > \
Forward/FWD_UNIQ_PKID.tr
cat Forward/FWD_UNIQ_PKID.tr | awk -F " " 'END{print NR}' > \
Forward/FWD_UNIQ_PKID_Number.tr
# Create a file with all packets received with success, field Packet ID
cat Trace_Cleaned.tr | awk -F" " '{if($1=="r" && $4=="AGT"){{print \mkdir -pv PDR
	$6}}}' > Forward/RCV.tr
rm -v Forward/UNIQ_PKID_RCV_F.tr
cat Forward/RCV.tr | awk -F " " '{print}' > Forward/UNIQ_PKID_RCV_F.tr
cat Forward/FWD_UNIQ_PKID.tr | awk -F " " '{print}' >> Forward/UNIQ_PKID_RCV_F.tr	
# Check which packets have been forwarded once
sort -n Forward/UNIQ_PKID_RCV_F.tr | uniq -d > Forward/FWD_Effective.tr 
awk -F" " 'END { print NR}' Forward/FWD_Effective.tr > \
Forward/FWD_Effective_Number.tr 
#Calculates the Packet Forwarding Rate #Calculates the Packet Forwarding Rate 
cat Forward/FWD_UNIQ_PKID_Number.tr > Forward/Forward_TMP_SUCCESS.tr 
cat Forward/FWD_Effective_Number.tr >> Forward/Forward_TMP_SUCCESS.tr 
cat Forward/Forward_TMP_SUCCESS.tr | awk -F " " '{ 
FWD[NR] = $0
} END {	
		SUCCESS = (FWD[2]/FWD[1])*100
		printf("%.f %",SUCCESS)
}' > Forward/Forward_SUCCESS.tr 
echo "End Forward Calculation!!!"

#End-to-End Delay Calculation
echo "Extracting End-to-End Delay..."
mkdir -pv Delay
rm Delay/media.tr
for conta in $(seq 0 59);
do
cat Trace_R_S.tr | awk -F " " '{   
	if($1 == "s" && $3=="'$conta'" && $4 == "AGT"){
		s_pacote[$6] = $2
		svetor[$6]=$6			
	}
	if($1 == "r" && $4 == "AGT"){
		r_pacote[$6] = $2
		rvetor[$6]=$6
	}
} END {	
	for(t = 0; t < NR; t++){
	  if(t in r_pacote && t in s_pacote && t in svetor && t in rvetor){
		 if(svetor[t]==rvetor[t]){	
				delay = (r_pacote[t] - s_pacote[t])*1000
				printf ("%3.9f\n",delay)
			}
		}
	}
}' > Delay/Delay_$conta.tr
#Check if you have some empty file and writes a value for the Delay calculus is computed without errors..
if [ -s Delay/Delay_$conta.tr ]; then
#Average Delay by Node
cat Delay/Delay_$conta.tr |awk -F" " '{
Vetor_media[NR] = $0
} END {
	for(m = 1; m <= NR; m++){
	soma = soma + Vetor_media[m]	
	}
	media = (soma/NR)
	printf("%3.9f",media)
}' > Delay/Media_Delay_$conta.tr
awk -F" " '{print}' Delay/Media_Delay_$conta.tr >> Delay/media.tr
fi
done;
# Global Average Delay
cat Delay/media.tr | awk -F" " '{
Vetor_media[NR] = $0
} END {
	for(m = 1; m <= NR; m++){
	soma = soma + Vetor_media[m]	
	}
	media = (soma/NR)
	printf("%3.6f",media)
}' > Delay/MediaGlobal_At.tr
echo  "End Delay Calculation ..."

# Jitter Calculation
echo "Extracting Jitter..."
mkdir -pv Jitter
for conta in $(seq 0 59);
do
cat Delay/Delay_$conta.tr | awk -F " " '{
vetor_Delay[NR] = $0
} END {	
	n = 1
	for(i = 0;i < NR; i++){
		jitter = vetor_Delay[n] - vetor_Delay[i]
		if(jitter < 0){
			jitter = (jitter * -1)
		}	
		printf("%3.9f\n",jitter)
		n++
	}
}' > Jitter/Jitter_$conta.tr
# Average Jitter
cat Jitter/Jitter_$conta.tr |awk -F" " '{
Vetor_media[NR] = $0
} END {
	for(j = 1; j <= NR; j++){
	soma = soma + Vetor_media[j]	
	}
	media = soma/NR
	printf("%3.9f",media)
}' > Jitter/Media_Jitter_$conta.tr
done;
# Global Average Jitter
rm Jitter/media.tr
for conta in $(seq 0 59);
do
awk -F" " '{print}' Jitter/Media_Jitter_$conta.tr >> Jitter/media.tr
done;
cat Jitter/media.tr | awk -F" " '{
Vetor_media[NR] = $0
} END {
	for(m = 1; m <= NR; m++){
	soma = soma + Vetor_media[m]	
	}
	media = soma/NR
	printf("%3.9f",media)
}' > Jitter/MediaGlobal_Jt.tr
echo "End Jitter Calculation..."

#Packet Delivery Rate Calc
echo "Start PDR..."
mkdir -pv PDR
awk -v S=$s -v R=$r -F " " 'BEGIN {
	PDR = (R/S)*100;
	{print PDR}
}' > PDR/PDR.p
echo "Finish PDR..."

#Stores the average of 'n' simulations in a single file.
echo "Extracting Simulation Result ... Please wait"
echo "SIMULATION $sim" >> Simulation_Result.result
echo "Generated Packets:" >> Simulation_Result.result
awk -F" " 'END { print NR }' Packet_Loss/S.tr >> Simulation_Result.result
echo "Throughput:" >> Simulation_Result.result
cat Throughput/Media_Throughput.tr >> Simulation_Result.result
echo "\nEnergy Consumption:" >> Simulation_Result.result
cat Energy/MediaGlobal_En.e >> Simulation_Result.result
echo "\nLoss by Selfishness:" >> Simulation_Result.result
cat Packet_Loss/Dropped_by_Selfish_Nodes.s | awk -F" " 'END {\
Vetor_media[NR] = $0
} END {
	for(m = 1; m <= NR; m++){
	soma = soma + Vetor_media[m]	
	}
	printf("%.f",soma)}' >> Simulation_Result.result
echo "\nTotal Loss Units:" >> Simulation_Result.result
cat Packet_Loss/PLR_U.p >> Simulation_Result.result
echo "Total Loss Percentage:" >> Simulation_Result.result
cat Packet_Loss/PLR_R.p >> Simulation_Result.result
echo "Overhead Units:" >> Simulation_Result.result
cat Overhead/Overhead.tr >> Simulation_Result.result
echo "Overhead (OverByteSend/DataByteRecv):" >> Simulation_Result.result
cat Overhead/Overhead_R.tr >> Simulation_Result.result
echo "Forward Percentage:" >> Simulation_Result.result
cat Forward/Forward_SUCCESS.tr >> Simulation_Result.result
echo "\nDelay (ms):" >> Simulation_Result.result
cat Delay/MediaGlobal_At.tr >> Simulation_Result.result
echo "\nJitter (ms):" >> Simulation_Result.result
cat Jitter/MediaGlobal_Jt.tr >> Simulation_Result.result
echo "\nPDR (%):" >> Simulation_Result.result
cat PDR/PDR.p >> Simulation_Result.result
echo "\n"
done;
echo "\nEND SIMULATION\n\n" >> Simulation_Result.result
cat Simulation_Result.result | sed -e 's/\./\,/' > Resultado_Final.result
dialog \
--title 'WARNING' \
--msgbox 'End of Script!!!' \
6 40
dialog \
--title 'RESULT'  \
--textbox Simulation_Result.result \
0 40
