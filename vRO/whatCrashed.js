// Use vCenter events to determine when a host has been restarted by HA

System.log("Initialize all HA Events of the infrastructure minus "+howLongAgo+" hours");
//Initialize all the Events of the infrastructure minus 24 hours
var vcEventFilterSpec = new VcEventFilterSpec() ;
var vcEventFilterSpecByTime = new VcEventFilterSpecByTime() ;
var vcEventManager = vCenter.eventManager;
var HostEvents = [];

var beginTime = new Date();

beginTime.setHours(beginTime.getHours()-howLongAgo);

vcEventFilterSpecByTime.beginTime = beginTime;


vcEventFilterSpec.time = vcEventFilterSpecByTime;

var collector = vcEventManager.createCollectorForEvents(vcEventFilterSpec);

//Define Max task number per Collector (999 maximum)
var tasknumber = 100;
var tasks =[];


var dummy = collector.rewindCollector();
var tasks = collector.readNextEvents(tasknumber);

while (tasks.length == tasknumber) {
    var last = tasks.length-1;
	System.log("Number of event to analyze: "+tasks.length);
	System.log("First Event :"+tasks[0].createdTime);
	System.log("Last event :"+tasks[last].createdTime);
	System.log("-----------------------------------");
	for each (var task in tasks){
    	if(task.fullFormattedMessage != undefined ) {
    		System.log(task.createdTime+" "+task.fullFormattedMessage);
			//search HA event
			if(task.fullFormattedMessage.indexOf("restarted")!= -1) {System.log(task.createdTime+" "+task.fullFormattedMessage);}
    	}
	}
	var tasks = collector.readNextEvents(tasknumber);
}

var last = tasks.length-1;
for each (var task in tasks){
	if(task.fullFormattedMessage != undefined ) {
		System.log(task.createdTime+" "+task.fullFormattedMessage);
		//search HA event
		if(task.fullFormattedMessage.indexOf("restarted")!= -1) {System.log(task.createdTime+" "+task.fullFormattedMessage);}
	}
}

collector.destroyCollector();
