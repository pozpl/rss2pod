/**
 * @author pozpl
 */

/*dojo.require("dojo.parser");
 dojo.require("dijit.form.Button");
 dojo.require("dijit.form.TextBox");
 dojo.require("dijit.Dialog");
 dojo.require("dijit.form.ValidationTextBox");
 dojo.require("dojox.validate.regexp");
 dojo.require("dijit.layout.ContentPane");
 dojo.require("dijit.layout.BorderContainer");
 dojo.require("dijit.layout.TabContainer");
 dojo.require("dijit.layout.AccordionContainer");
 dojo.require("dojo.cache");
 dojo.require("dojo.text");
 dojo.require("dojox.dtl");
 dojo.require("dojox.dtl.Context");
 dojo.require("dojox.dtl.dom");
 dojo.require("dojox.widget.Standby");

 dojo.require("dijit.TooltipDialog");
 */

require(["dojo/dom", 'dojo/_base/xhr',"dojo/domReady!", "dojo/parser", "dijit/form/Button", 
"dijit/form/TextBox", "dijit/Dialog", "dijit/form/ValidationTextBox", 
"dojox/validate/regexp", "dijit/layout/ContentPane", "dijit/layout/BorderContainer",
"dijit/layout/TabContainer", "dijit/layout/AccordionContainer", "dojo/text", 
"dojox/dtl", "dojox/dtl/Context", "dojox/dtl/dom", "dojox/widget/Standby", 
"dijit/TooltipDialog", "dijit/dijit"], function(dom, xhr) {
	
	
	var singlePodPanObj = new SinglePodPanel();
	var podPanelObj = new PodPanel(singlePodPanObj);
	var feedPanelObj = new FeedPanel();

	var userProfileStruct;
	var initInerfaceStandby;


	
	
	//dojo.addOnLoad(function(){
	initInerfaceStandby = new dojox.widget.Standby({
		target : "JsUIConteiner"
	});
	document.body.appendChild(initInerfaceStandby.domNode);
	initInerfaceStandby.startup();
	loadUserProfile();
	resize_window();

	function loadUserProfile() {
		initInerfaceStandby.show();
		xhr.get({
			// The following URL must match that used to test the server.
			url : "./podmanager.cgi",
			handleAs : "json",
			content : {
				rm : "auth_get_user_profile"
			},
			timeout : 15000, // Time in milliseconds
			// The LOAD function will be called on a successful response.
			load : function(response, ioArgs) {
				userProfileStruct = response;

				podPanelObj.init(userProfileStruct);
				singlePodPanObj.init(userProfileStruct);
				feedPanelObj.init(userProfileStruct);

				podPanelObj.regSinglePodPanel(singlePodPanObj);
				singlePodPanObj.regPodcastsPanel(podPanelObj);
				singlePodPanObj.regFeedsPanel(feedPanelObj);
				feedPanelObj.regSinglePodObj(singlePodPanObj);

				podPanelObj.showUserPodcasts();
				singlePodPanObj.showSinglePodData(userProfileStruct.pod_info['first_pod_id']);

				initInerfaceStandby.hide();
				return response;
			},
			// The ERROR function will be called in an error case.
			error : function(response) {
				initInerfaceStandby.hide();
				
				return response;
			}
		});
	}
	
	function resize_window() {
	var mainFraim = dom.byId("JsUIConteiner");
	var vs = dojo.window.getBox();
	var height = vs.h - 130;
	var weight = vs.w;
	if(weight < 1000) {
		weight = 1000;
	}
	if(height < 550) {
		height = 550;
	}
	dojo.style("JsUIConteiner", {
		"width" : weight + "px",
		"height" : height + "px",
	});
}

});
