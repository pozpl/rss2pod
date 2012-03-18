/**
 * @author pozpl
 */
//function PodPanel(singlePodPan){
define(["dojo/dom", 'dojo/_base/declare', "dojo/on","dojo/mouse", "dojo/query", "dojo/dom-construct",
"dojox/widget/Standby", "dojox/dtl", "dojox/dtl/Context"], 
function(dom, declare, on, mouse, query, domConstruct) {
	declare("PodPanel", null, {
		podNames : new Array(),
		addPodStandby : new dojox.widget.Standby({
			target : "podcastsPane"
		}),
		userProfileHandl : null,
		lastUnfolded : 0,
		singlePodPanel : null,
		podClickHndlr : null,
		
		constructor: function(args){
     	 //declare.safeMixin(this, args);
    	},
		
		getUserProfileHdl : function() {
			return this.userProfileHandl;
		},
		regSinglePodPanel : function(singlePodPanelObj) {
			this.singlePodPanel = singlePodPanelObj;
		},
		init_profile  : function(userProfileHdl) {
			this.userProfileHandl = userProfileHdl;
			//draw new button to add podcast
			var button = new dijit.form.Button({
				label : "Add new podcast",
				onClick : function() {
					// Do something:
					var addPodDial = dijit.byId("addPodcastDialog");
					if(addPodDial) {
						dojo.byId("podcast_name_input").value = "";
						addPodDial.show();
					}

				},
				id : "addPodcastButton"
			}).placeAt("podcastsAddButton");
			//this.addPodStandby = new dojox.widget.Standby({
			//	target : "podcastsPane"
			//});
			document.body.appendChild(this.addPodStandby.domNode);
			this.addPodStandby.startup();

			/*dojo.declare("DeletePodButtonWid", [dijit._Widget, dijit._Templated], {
			 templateString: "<div class='delPodArea'><img src='images/del_feed.png' width='24'/>Удалить подкаст</div>",
			 });*/

		},
		updateUserProfile : function() {
			var podPanObj = this;
			var userProfileHandl = this.userProfileHandl;
			dojo.xhrGet({
				// The following URL must match that used to test the server.
				url : "./podmanager.cgi",
				handleAs : "json",
				content : {
					rm : "auth_get_user_profile"
				},
				timeout : 15000, // Time in milliseconds
				// The LOAD function will be called on a successful response.
				load : function(response, ioArgs) {
					dojo.mixin(userProfileHandl, response);
					podPanObj.showUserPodcasts();
					podPanObj.singlePodPanel.showSinglePodData(userProfileHandl.pod_info['first_pod_id']);
					return response;
				},
				// The ERROR function will be called in an error case.
				error : function(response, ioArgs) {
					console.error("HTTP status code: ", ioArgs.xhr.status);
					var message = "";
					switch (ioargs.xhr.status) {
						case 404:
							message = "The requested page was not found";
							break;
						case 500:
							message = "The server reported an error.";
							break;
						case 407:
							message = "You need to authenticate with a proxy.";
							break;
						default:
							message = "Unknown error.";
					}

					alert(message);
					return response;
				}
			});
		},
		showUserPodcasts : function() {
			var podPanObj = this;
			domConstruct.empty("podcastsListPane");
			podPanObj.podNames = new Array();
			var userProfileHandl = this.userProfileHandl;
			var podItemTmplCont;
			podItemTmplCont = dom.byId("podTemplateField").innerHTML;
			var template = new dojox.dtl.Template(podItemTmplCont);

			dojo.forEach(userProfileHandl.pod_list, function(podcast_id, i) {
				var spodBackColor = "white";
				if((i % 2) > 0) {
					spodBackColor = "#dcdad5";
				} else {
					spodBackColor = "#eee"
				}

				var context = new dojox.dtl.Context({
					pod_name : userProfileHandl.pod_info[podcast_id].name,
					pod_name_id : "podcastname_" + podcast_id,
					pod_manage_id : "podcastmanage_" + podcast_id
				});

				var singlePod = domConstruct.create("div", {
					innerHTML : template.render(context),
					id : "podcastPane_" + podcast_id,
					dojoType : "dijit.layout.ContentPane",
					style : {
						background : spodBackColor,
						padding : "4px"
					}
				}, "podcastsListPane");

			});
			
			
			if(podPanObj.podClickHndlr){
				podPanObj.podClickHndlr.remove();
			}
			
			var podcastsList= dom.byId("podcastsListPane");
			
			
			podPanObj.podClickHndlr = on(podcastsList, 
				".pod_choise:click", 
				function(evt) {
					
					var podIndx = this.id.substring("podcastname_".length, this.id.length);
					//alert(feedIndx);
					podPanObj.singlePodPanel.showSinglePodData(podIndx);
				}
			);
			
			/*dojo.forEach(podPanObj.eventConnections, dojo.disconnect);
			podPanObj.eventConnections = query("[id^='podcastname_']").connect("onclick", function(evt) {
				var podIndx = evt.target.id.substring("podcastPane_".length, evt.target.id.length);
				podPanObj.singlePodPanel.showSinglePodData(podIndx);
			});*/
			/*
			 var tmp_event_array = dojo.query("[id^='podcastname_']").connect("onclick", function(evt){
			 var podIndx = evt.currentTarget.id.substring("podcastPane_".length, evt.currentTarget.id.length);
			 console.log("FeedIndx " + podIndx + " evtid " + evt.currentTarget);
			 var nodeToUnfold = "podcastmanage_" + podIndx;
			 var ruleNode = "podcastname_" + podIndx;
			 podPanObj.unfoldPodManagEls(podIndx, nodeToUnfold, ruleNode);
			 });
			 dojo.forEach(tmp_event_array, function(item, i){
			 podPanObj.eventConnections.push(item);
			 });*/

		},
		addNewPodcast : function(formAttrs) {
			var podPadObj = this;
			this.addPodStandby.show();
			dojo.xhrGet({
				// The following URL must match that used to test the server.
				url : "./podmanager.cgi",
				handleAs : "text",
				content : {
					rm : "auth_add_podcast",
					podcast_name : formAttrs.podcast_name_input
				},

				timeout : 5000, // Time in milliseconds
				// The LOAD function will be called on a successful response.
				load : function(response, ioArgs) {
					podPadObj.addPodStandby.hide();
					//dojo.byId("replace").innerHTML = response; //
					if(response == "ok") {
						podPadObj.updateUserProfile();
					} else {
						//alert(response);
						//fire dialog that we cant do somthing
					}
					return response;
				},
				// The ERROR function will be called in an error case.
				error : function(response, ioArgs) {
					podPadObj.addPodStandby.hide();
					console.error("HTTP status code: ", ioArgs.xhr.status);
					var message = "";
					switch (ioargs.xhr.status) {
						case 404:
							message = "The requested page was not found";
							break;
						case 500:
							message = "The server reported an error.";
							break;
						case 407:
							message = "You need to authenticate with a proxy.";
							break;
						default:
							message = "Unknown error.";
					}

					alert(message);
					return response;
				}
			});
		},
		unfoldPodManagEls : function(podIndx, nodeToUnfold, ruleNode) {
			var podPanObj = this;

			if(!dojo.hasAttr(ruleNode, "appear")) {
				dojo.attr(ruleNode, "appear", "appear");
				//dojo.toggleClass(nodeToUnfold, "delPodArea");

				if(podPanObj.lastUnfolded != 0) {
					if(dojo.byId(podPanObj.lastUnfolded) && dojo.hasAttr(podPanObj.lastUnfolded, "appear")) {
						//dojo.toggleClass(podPanObj.lastUnfolded, "delPodArea");
						dojo.removeAttr(podPanObj.lastUnfolded, "appear");
					}
					var buttonW = dijit.byId("delte_podcast_button");
					if(buttonW) {
						buttonW.destroy();
					}
				}
				podPanObj.lastUnfolded = ruleNode;

				var button = new DeletePodButtonWid({
					//label: "Удалить подкаст",
					onClick : function() {
						podPanObj.deletePodcast(podIndx);
					},
					id : "delte_podcast_button",

				}).placeAt(nodeToUnfold);
				/*var button = new dijit.form.Button({
				 label: "Удалить подкаст",
				 onClick: function(){
				 podPanObj.deletePodcast(podIndx);
				 },
				 id: "delte_podcast_button",
				 iconClass: "dijitEditorIcon buttonCustomIcon ",
				 }).placeAt(nodeToUnfold);*/
			} else {
				podPanObj.lastUnfolded = 0;
				//dojo.toggleClass(nodeToUnfold, "delPodArea");
				dojo.removeAttr(ruleNode, "appear");
				var buttonW = dijit.byId("delte_podcast_button");
				if(buttonW) {
					buttonW.destroy();
				}
			}

		},
		deletePodcast : function(podId) {
			//var singlePodPad = this;
			var podcastsPan = this;
			//var theSinglePod = this.singlePodName;
			var userProfileHandl = this.userProfileHandl;

			dojo.xhrGet({
				// The following URL must match that used to test the server.
				url : "./podmanager.cgi",
				handleAs : "text",
				content : {
					rm : "auth_delete_single_pod_data",
					pod_name_pase64 : userProfileHandl.pod_info[podId].name_base64
				},
				timeout : 15000, // Time in milliseconds
				// The LOAD function will be called on a successful response.
				load : function(response, ioArgs) {
					if(response == "ok") {
						//All OK
						//alert("CAll update");
						//podcastsPan.lastUnfolded = 0;
						podcastsPan.updateUserProfile();
					}
					return response;
				},
				// The ERROR function will be called in an error case.
				error : function(response, ioArgs) {
					console.error("HTTP status code: ", ioArgs.xhr.status);
					var message = "";
					switch (ioargs.xhr.status) {
						case 404:
							message = "The requested page was not found";
							break;
						case 500:
							message = "The server reported an error.";
							break;
						case 407:
							message = "You need to authenticate with a proxy.";
							break;
						default:
							message = "Unknown error.";
					}

					alert(message);
					return response;
				}
			});

		},
	});
});
