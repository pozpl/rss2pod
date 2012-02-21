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

require(["dojo/dom", 'dojo/_base/xhr', 'dojo/_base/declare', 
'rss2pod/pod_panel_logic', 'rss2pod/feeds_panel_logic', 'rss2pod/single_pod_panel_logic', 'rss2pod/rss_reader_panel', 
"dojo/domReady!", "dojo/parser", "dijit/form/Button", "dijit/form/TextBox", "dijit/Dialog", 
"dijit/form/ValidationTextBox", "dojox/validate/regexp", "dijit/layout/ContentPane", 
"dijit/layout/BorderContainer", "dijit/layout/TabContainer", "dijit/layout/AccordionContainer",
 "dojo/text", "dojox/dtl", "dojox/dtl/Context", "dojox/dtl/dom", "dojox/widget/Standby", 
 "dijit/TooltipDialog", "dijit/dijit"], function(dom, xhr, declare) {
	
	declare("Rss2PodManager", null, {

		singlePodPanObj : null,
		podPanelObj : null,
		feedPanelObj : null,
		userProfileStruct : null,
		initInerfaceStandby : null,

		constructor : function() {
			this.singlePodPanObj = new SinglePodPanel();
			this.podPanelObj = new PodPanel(this.singlePodPanObj);
			this.feedPanelObj = new FeedPanel();
		},
		load : function() {
			//dojo.addOnLoad(function(){
			this.initInerfaceStandby = new dojox.widget.Standby({
				target : "JsUIConteiner"
			});
			document.body.appendChild(this.initInerfaceStandby.domNode);
			this.initInerfaceStandby.startup();
			this.loadUserProfile();
			this.resize_window(dom);
		},
		resize_window : function() {
			var mainFraim = dom.byId("JsUIConteiner");
			var vs = dojo.window.getBox();
			var height = vs.h - 130;
			var weight = vs.w;
			if(weight < 1000) {
				weight = 944;
			}
			if(height < 550) {
				height = 550;
			}
			dojo.style("JsUIConteiner", {
				"width" : weight + "px",
				"height" : height + "px",
			});
		},
		loadUserProfile : function() {
			var rss2podMan = this;
			this.initInerfaceStandby.show();
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
					rss2podMan.userProfileStruct = response;
					rss2podMan.podPanelObj.init_profile(rss2podMan.userProfileStruct);					
					rss2podMan.singlePodPanObj.init_profile(rss2podMan.userProfileStruct);					
					rss2podMan.feedPanelObj.init_profile(rss2podMan.userProfileStruct);

					rss2podMan.podPanelObj.regSinglePodPanel(rss2podMan.singlePodPanObj);
					rss2podMan.singlePodPanObj.regPodcastsPanel(rss2podMan.podPanelObj);
					rss2podMan.singlePodPanObj.regFeedsPanel(rss2podMan.feedPanelObj);
					rss2podMan.feedPanelObj.regSinglePodObj(rss2podMan.singlePodPanObj);

					rss2podMan.podPanelObj.showUserPodcasts();
					rss2podMan.singlePodPanObj.showSinglePodData(rss2podMan.userProfileStruct.pod_info['first_pod_id']);

					rss2podMan.initInerfaceStandby.hide();
					return response;
				},
				// The ERROR function will be called in an error case.
				error : function(response) {
					rss2podMan.initInerfaceStandby.hide();

					return response;
				}
			});
		},
	});
	
	
	var rss2podManagerObj = new Rss2PodManager();
	rss2podManagerObj.load();
	
});
