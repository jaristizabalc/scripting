// Workflow to generate a specification report, requires Cisco UCS plugin
// Data is obtained from all the vCenters managed by vRO

function getHostSerial(domainArray,esxiHost) {
	var blade = null;
	for (var i = 0; i < domainArray.length ; i++){
		blade = System.getModule("com.cisco.ucs.vcoplugin.basic").getManagedObjects(domainArray[i], null, "blade","uuid="+esxiHost.hardware.systemInfo.uuid,false,false,false);
		if(blade != null){ break; }
	}
	if(blade != null){ return blade[0].serial; }
	else { return null;}
}
function getClustersDatacenter(datacenter){
	var clusters = new Array;  
	var folder = datacenter.hostFolder;  
	var children = folder.childEntity;  
	for each (child in children){  
    	if (child instanceof VcClusterComputeResource){clusters.push(child);}	  
	}
	return clusters;  
}
function getHostsDatacenter(datacenter){
	var hosts = new Array;  
	var folder = datacenter.hostFolder;  
	var children = folder.childEntity;  
	for each (child in children){  
    	if (child instanceof VcHostSystem){hosts.push(child);}	  
	}
	return hosts;  
}
var domains = UcsmActionUtils.getAllUcsDomains();
var blades;
var cluster;
var city;
var workload;
var serial;
var location;
var hostState;
var allDatacenters = VcPlugin.getAllDatacenters();
var byteToGiga=1024*1024*1024;
var today = new Date();
var dd = today.getDate();
var mm = today.getMonth()+1; //January is 0!
var yyyy = today.getFullYear();
var legacy;
if(dd<10) { dd='0'+dd  } 
if(mm<10) { mm='0'+mm  } 
today = mm+'_'+dd+'_'+yyyy;
var fileLocation = "/var/lib/vco/reports/specs_report_"+today+".csv";
System.log("Generating: "+fileLocation+" ...");
var fw = new FileWriter(fileLocation);
fw.open();
fw.clean();
fw.write("Name,State,Manufacturer,Sockets,ProcessorType,Model,Serial,vCenter,Cluster,Datacenter,City,LocnGroup,VMcount,VMcountWin,VMcountLin,VMCountDesk,VMCountUNK,Workload,MemoryUsage%,Legacy,VMCountOff,\r\n");
for (var i = 0; i < allDatacenters.length ; i++){
	var computeResources = System.getModule("org.utilities.vmw").getAllComputeResources(allDatacenters[i]);
	for (var j = 0; j < computeResources.length ; j++){
		cluster =null;
		if(computeResources[j] instanceof VcComputeResource){cluster = "Not Clustered";}
		else if(computeResources[j] instanceof VcClusterComputeResource) {cluster = computeResources[j].name;}
		//get GuestOS counts
		var allHosts = computeResources[j].host;
		for (var k = 0; k < allHosts.length ; k++) {
			var linux = 0;
			var windows = 0;
			var desktop = 0;
			var unk = 0;
			var off = 0;
			for (var l =0; l< allHosts[k].vm.length ; l++) {
				//exclude powered off VMs
				if(allHosts[k].vm[l].runtime.powerState.value == "poweredOn") {
					guestOS = allHosts[k].vm[l].guest.guestFullName;
					if (guestOS == null) {unk++;}
					else {
						if ((guestOS.indexOf("Microsoft Windows 7") > -1) || (guestOS.indexOf("Microsoft Windows XP") > -1) || (guestOS.indexOf("Microsoft Windows Vista") > -1)){desktop++;}
				    	else if((guestOS.indexOf("Linux") > -1) || (guestOS.indexOf("Other") > -1)) {linux++;}
				    	else if ((guestOS.indexOf("Microsoft Windows Server") > -1)) {windows++;}
				    	else {unk++;}
					}
				}
				else {
					off++;	
				}
			}
			//Identify VDI vCenters
			if(cluster.indexOf("VDI",0) != -1){workload = "VDI";}
			else {workload = "SERVER";}
			legacy ="LE";
			vcenterID = allHosts[k].sdkConnection.name.substring(8,11);
			if((vcenterID == "vcw") || (vcenterID == "vcv") || (vcenterID == "vcu") || (vcenterID == "vcz") || (vcenterID == "vcy") || (vcenterID == "vcx") || (vcenterID == "gtn")) {
				legacy = "LS";
			}
			else {legacy ="LE";}
			//Identify City aby Datacenter Name
			switch(allDatacenters[i].name) {
				case "CARROLLTON": city = "Dallas";break;
				case "CALGARY": city = "Calgary";break;
				case "CHATHAM": city = "Chatham";break;
				case "HOUSTON-3rdFloorDC": city = "Houston";break;
				case "LEBANON": city = "Lebanon";break;
				case "NASHVILLE": city = "Nashville";break;
				case "LONDON": city = "London";break;
				case "WALTHAM": city = "Waltham";break;
				case "New Creek": city = "New Creek";break;
				case "SSEEOO": city = "Edmonton";break;
				case "SSSSEO": city = "Edmonton";break;
				case "Fort Nelson": city = "Fort Nelson";break;
				case "DOWNT": city = "Edmonton";break;
				case "VPC": city = "Toronto";break;
				case "GAZIFERE": city = "Gazifere";break;
				case "CYRUS ONE - DALLAS": city = "Dallas";break;
				case "Dallas": city = "Dallas";break;
				case "Thorold": city = "Thorold";break;
				case "Superior": city = "Superior";break;
				case "Tower": city = "Edmonton";break;
				case "Edmonton Manulife": city = "Edmonton";break;
				case "Edmonton Site 2": city = "Edmonton";break;
				case "Regina": city = "Regina";break;
				case "Sarnia": city = "Sarnia";break;
				case "Calgary": city = "Calgary";break;
				case "Norman Wells": city = "Norman Wells";break;
				case "HOUSTON 1100": city = "Houston";break;
				case "OTTAWA": city = "Ottawa";break;
				case "Houston": city = "Houston";break;
				case "HOUSTON": city = "Houston";break;
				case "THOROLD": city = "Thorold";break;
				default : city ="Unknown";
			}
			//Identify LocnGroup by Cluster Name
			switch(cluster) {
				//Define cluster name to location here
				case "Not Clustered": location = "Not Clustered";break;
				default : location = "Unknown";
			}
			//Get Serial if Cisco UCS
			serial="";
			var props = allHosts[k].summary.hardware.otherIdentifyingInfo;
			if (props != null) {
				//if a host has mutiple serials get the second one only, Chassis-Blade condition, the first serial can be discarted
				for each (property in props){
    				if(property.identifierType.label == "Service tag"){serial = property.identifierValue;}
				}
			}
			else {serial = null;}
			//Identify if host is in Maintenance mode
			try {
			if (allHosts[k].runtime.inMaintenanceMode == true) {hostState = "maintenance";}
			else {hostState = allHosts[k].runtime.connectionState.value;}
			}
			catch(err) {
				hostState = "undetermined";
				System.log(allHosts[k].name+'---'+err);
			}
			//get Memory Used on host
			var hostMemory = System.formatNumber(allHosts[k].hardware.memorySize/byteToGiga,"0.");
			var hostUsedMemory = System.formatNumber(allHosts[k].summary.quickStats.overallMemoryUsage/1000,"0.000"); // Returns in MB  
			var hostUsedPercent = Math.round((hostUsedMemory/hostMemory)*100);
			
			var line = allHosts[k].name+','+hostState+','+(allHosts[k].summary.hardware.vendor).replace(',',' ')+','+allHosts[k].summary.hardware.numCpuPkgs+','+
		           allHosts[k].summary.hardware.cpuModel+','+allHosts[k].summary.hardware.model+','+serial+','+
		           allHosts[k].sdkConnection.name+','+cluster+','+allDatacenters[i].name+','+city+','+location+','+(windows+linux+desktop+unk)+','+windows+','+linux+','+
				   desktop+','+unk+','+workload+','+hostUsedPercent+','+legacy+','+off;
			System.log(line);
			fw.write(line+"\r\n");	
		}
	}			
}
fw.close();

var cmd = new String();
cmd = "chmod 644 "+fileLocation;
System.log("Executing cmd: " + cmd);
var command = new Command(cmd);
command.execute(true);
var resultOutput = command.output;
System.log("resultOutput: " + resultOutput);
