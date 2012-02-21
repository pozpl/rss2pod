/**
 * @author pozpl
 */
define(["dojo/dom", 'dojo/_base/declare', "dojo/on","dojo/mouse", "dojo/query",
		"dojox/widget/Standby", 'dijit/form/Button'], function(dom, declare, on, mouse, query) {
	//require(['dojo/_base/declare'], function(declare) {
	declare("SinglePodPanel", null, {
		//function SinglePodPanel(){

		podId : 0,
		podPanelHandle : null,
		feedsPanelHandle : null,
		//Hash that includes all information sended from server
		feedsInf : null,
		userProfileHandl : null,
		addDownloadStandby : null,
		//List of nodes for podcast rss feeds connect events
		//feedsNodesConn : [],
		feedsParentEvtHdlr : null,
		
		constructor: function(args){
     	 //declare.safeMixin(this, args);
    	},

		getUserProfileHdl : function() {
			return this.userProfileHandl;
		},
		regPodcastsPanel : function(podcastsPanel) {
			this.podPanelHandle = podcastsPanel;
		},
		regFeedsPanel : function(feedsPanelHandle) {
			this.feedsPanelHandle = feedsPanelHandle;
		},
		getPodId : function() {
			return this.podId;
		},
		init_profile : function(userProfileHdl) {			
			var singlePodObj = this;
			this.userProfileHandl = userProfileHdl;
			this.podId = userProfileHdl.pod_info.first_pod_id;			
			var button = new dijit.form.Button({
				label : "Delete this podcast",
				onClick : function() {
					singlePodObj.deletePodcast();
				},
				id : "delCurrentPodcastButton"
			}).placeAt("delPodcastButtonArea");

			this.addDownloadStandby = new dojox.widget.Standby({
				target : "singlePodPane"
			});
			document.body.appendChild(this.addDownloadStandby.domNode);
			this.addDownloadStandby.startup();

			var downlNode = dojo.byId("getPodArea");
			//dojo.byId("getPodHref");
			dojo.connect(downlNode, "onclick", this, this.genAudioPod);

			//dojo.connect(dijit.byId("delCurrentPodcastButton"), "onClick", this, this.deletePodcast);
		},
		deletePodcast : function() {
			var singlePodPad = this;
			var podcastsPan = this.podPanelHandle;
			var theSinglePod = this.singlePodName;
			var userProfileHandl = this.userProfileHandl;

			dojo.xhrGet({
				// The following URL must match that used to test the server.
				url : "./podmanager.cgi",
				handleAs : "text",
				content : {
					rm : "auth_delete_single_pod_data",
					pod_name_pase64 : userProfileHandl.pod_info[singlePodPad.podId].name_base64
				},
				timeout : 15000, // Time in milliseconds
				// The LOAD function will be called on a successful response.
				load : function(response, ioArgs) {
					if(response == "ok") {
						//All OK
						//alert("CAll update");
						singlePodPad.updateUserProfile();

						//singlePodPad.showSinglePodData(0);
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
		showSinglePodData : function(podId) {
			var singlePodPad = this;
			var feedsPanelHandle = this.feedsPanelHandle;
			var userProfileHandl = this.userProfileHandl;
			var singlePod = dojo.byId("singlePodNameArea");

			singlePodPad.podId = podId;

			singlePod.innerHTML = userProfileHandl.pod_info[podId].name;

			//show rss list for this podcast
			var	feedItemTmplCont = dom.byId("feedTemplateField").innerHTML;
			var feedTemplate = new dojox.dtl.Template(feedItemTmplCont);
			dojo.empty("podRssList");
			var feedIdTitleMap = userProfileHandl.feeds_title_mapping;
			dojo.forEach(userProfileHandl.pod_info[podId].pod_feeds, function(feed_id, i) {
				var spodBackColor = "white";
				if((i % 2) > 0) {
					spodBackColor = "#dcdad5";
				} else {
					spodBackColor = "#eee"
				}

				var context = new dojox.dtl.Context({
					feed_name : feedIdTitleMap[feed_id],
					del_id : "singlePodDelFeed_" + feed_id,
					show_add_button : false
				});

				singlePodPad.feedsNames = feedIdTitleMap[feed_id];

				var singlePod = dojo.create("div", {
					innerHTML : feedTemplate.render(context),
					id : "podFeedPane_" + feed_id,
					dojoType : "dijit.layout.ContentPane",
					style : {
						background : spodBackColor
					}
				}, "podRssList");

			});
			//Update border container
			require('dojo/dom', function(dom) {
				dom.byId("borderContainer").resize();
			});
			
			//dojo.forEach(singlePod.feedsNodesConn, dojo.disconnect);
			if(singlePodPad.feedsParentEvtHdlr){
				singlePodPad.feedsParentEvtHdlr.remove();
			}
			singlePodPad.feedsParentEvtHdlr = dom.byId("podRssList");
			on(singlePodPad.feedsParentEvtHdlr, 
				".del_feed:click", 
				function(evt) {
					
					var feedIndx = this.id.substring("singlePodDelFeed_".length, this.id.length);
					alert(feedIndx);
					singlePodPad.delFeedFromActivPod(feedIndx, singlePodPad.getPodId())
				}
			);
				
			//singlePod.feedsNodesConn = dojo.query("[id^='singlePodDelFeed_']").connect("onclick", function(evt) {
			//	var feedIndx = evt.currentTarget.id.substring("singlePodDelFeed_".length, evt.currentTarget.id.length);
			//	singlePodPad.delFeedFromActivPod(feedIndx, singlePodPad.getPodId());
			//});

			singlePodPad.getOldPodNames();

			feedsPanelHandle.showUserFeeds();
		},
		updateUserProfile : function() {
			var singlePodPad = this;
			var feedsPanelHandle = this.feedsPanelHandle;
			var userProfileHandl = this.userProfileHandl;
			podPanelObj = this.podPanelHandle;
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
					podPanelObj.showUserPodcasts();

					singlePodPanObj.showSinglePodData(userProfileHandl.pod_info['first_pod_id']);

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
		delFeedFromActivPod : function(feedIdx, podId) {
			var singlePodPad = this;
			var feedsPanelHandle = this.feedsPanelHandle
			var userProfileHandl = this.userProfileHandl;

			var delElIdx = dojo.indexOf(((userProfileHandl['pod_info'])[podId])['pod_feeds'], feedIdx);
			if(delElIdx >= 0) {
				((userProfileHandl['pod_info'])[podId])['pod_feeds'].splice(delElIdx, 1);
			}
			singlePodPad.showSinglePodData(podId);
			feedsPanelHandle.showUserFeeds();

			dojo.xhrGet({
				// The following URL must match that used to test the server.
				url : "./podmanager.cgi",
				handleAs : "text",
				content : {
					rm : "auht_del_feed_from_podcast",
					feed_id : feedIdx, //number of feed in user feeds list
					pod_id : podId
				},

				timeout : 5000, // Time in milliseconds
				// The LOAD function will be called on a successful response.
				load : function(response, ioArgs) {
					//dojo.byId("replace").innerHTML = response; //
					if(response == "ok") {
						//later this will require

					} else {
						//alert(response);
						//fire dialog that we cant do somthing
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
		genAudioPod : function() {
			var singlePodPad = this;
			var podId = singlePodPad.getPodId();
			singlePodPad.addDownloadStandby.show();
			var dataTime = singlePodPad.getCalendarDate() + " " + singlePodPad.getClockTime();
			dojo.xhrGet({
				// The following URL must match that used to test the server.
				url : "./podmanager.cgi",
				handleAs : "text",
				content : {
					rm : "auth_gen_podcast_file",
					pod_id : podId,
					datatime : dataTime
				},

				timeout : 45000, // Time in milliseconds
				// The LOAD function will be called on a successful response.
				load : function(response, ioArgs) {
					if(response == "ok") {
						singlePodPad.checkAudioPodAvail(podId);
					} else {
						singlePodPad.addDownloadStandby.hide();
					}
					return response;
				},
				// The ERROR function will be called in an error case.
				error : function(response, ioArgs) {
					singlePodPad.addDownloadStandby.hide();
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
		checkAudioPodAvail : function(podId) {
			var singlePodPad = this;
			//var podId = singlePodPad.getPodId();
			dojo.xhrGet({
				// The following URL must match that used to test the server.
				url : "./podmanager.cgi",
				handleAs : "text",
				content : {
					rm : "auth_check_pod_complite",
					pod_id : podId
				},

				timeout : 45000, // Time in milliseconds
				// The LOAD function will be called on a successful response.
				load : function(response, ioArgs) {
					switch (response) {
						case "ok":
							singlePodPad.addDownloadStandby.hide();
							//singlePodPad.getOldPodNames();
							dojo.doc.location = "podmanager.cgi?rm=auth_get_podcast_file&pod_id=" + podId + "&old_pod_num=0";
							break;
						case "empty_file":
							singlePodPad.addDownloadStandby.hide();
							var feedNotFoundDial = new dijit.Dialog({
								title : "Nothing to download",
								content : "There is no new podcasts.",
								style : "width: 300px"
							});
							feedNotFoundDial.show();
							break;
						case "internal_error":
							singlePodPad.addDownloadStandby.hide();
							var someErrorDial = new dijit.Dialog({
								title : "Something bad hapened",
								content : "Sorry, but now we can not process your query." + response,
								style : "width: 300px"
							});
							someErrorDial.show();
							break;
						case "whait":
							var run_this = dojo.hitch(singlePodPad, singlePodPad.checkAudioPodAvail, podId);
							setTimeout(function() {
								run_this();
							}, 1000);
							break;
						default:

					}

					return response;
				},
				// The ERROR function will be called in an error case.
				error : function(response, ioArgs) {
					singlePodPad.addDownloadStandby.hide();
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
		getOldPodNames : function() {
			var singlePodPad = this;
			var podId = singlePodPad.getPodId();
			dojo.xhrGet({
				// The following URL must match that used to test the server.
				url : "./podmanager.cgi",
				handleAs : "json",
				content : {
					rm : "auth_get_old_pod_files_lables_json",
					pod_id : podId
				},

				timeout : 45000, // Time in milliseconds
				// The LOAD function will be called on a successful response.
				load : function(response, ioArgs) {
					if(response != null && response.length > 0) {
						var menu = new dijit.Menu({
							style : "display: none;"
						});
						dojo.forEach(response, function(pod_item, i) {

							var menuItem1 = new dijit.MenuItem({
								label : pod_item,
								onClick : function() {
									//alert('hi');
									dojo.doc.location = "podmanager.cgi?rm=auth_get_podcast_file&pod_id=" + podId + "&old_pod_num=" + i;
								}
							});
							menu.addChild(menuItem1);
						});
						var previous_button = dijit.byId("old_podcasts_dropdown_button");
						if(previous_button) {
							previous_button.destroy();
						}

						var button = new dijit.form.ComboButton({
							label : "Get your previous podcasts",
							dropDown : menu,
							id : "old_podcasts_dropdown_button"
						});
						dojo.byId("getOldPodcastsButton").appendChild(button.domNode);
					}
					return response;
				},
				// The ERROR function will be called in an error case.
				error : function(response, ioArgs) {
					singlePodPad.addDownloadStandby.hide();
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
		getCalendarDate : function() {
			var months = new Array(13);
			months[0] = "January";
			months[1] = "February";
			months[2] = "March";
			months[3] = "April";
			months[4] = "May";
			months[5] = "June";
			months[6] = "July";
			months[7] = "August";
			months[8] = "September";
			months[9] = "October";
			months[10] = "November";
			months[11] = "December";
			var now = new Date();
			var monthnumber = now.getMonth();
			var monthname = months[monthnumber];
			var monthday = now.getDate();
			var year = now.getYear();
			if(year < 2000) {
				year = year + 1900;
			}
			var dateString = monthname + ' ' + monthday + ', ' + year;
			return dateString;
		},
		getClockTime : function() {
			var now = new Date();
			var hour = now.getHours();
			var minute = now.getMinutes();
			var second = now.getSeconds();
			var ap = "AM";
			if(hour > 11) {
				ap = "PM";
			}
			if(hour > 12) {
				hour = hour - 12;
			}
			if(hour == 0) {
				hour = 12;
			}
			if(hour < 10) {
				hour = "0" + hour;
			}
			if(minute < 10) {
				minute = "0" + minute;
			}
			if(second < 10) {
				second = "0" + second;
			}
			var timeString = hour + ':' + minute + ':' + second + " " + ap;
			return timeString;
		},
	});
});
