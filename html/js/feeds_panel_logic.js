/**
 * @author pozpl
 */
define(["dojo/dom", 'dojo/_base/declare',  "dojo/on","dojo/mouse", "dojo/query", "dojo/dom-construct",
  "dojox/widget/Standby", 'dijit/form/Button', "dojox/dtl", "dojox/dtl/Context"], 
	   function(dom, declare, on, mouse, query, domConstruct) {
	declare("FeedPanel", null, {
		//function FeedPanel(){

		feedsNames : new Array(),
		podConrtrolHandler : null, //refferal to single pod controller object
		addFeedStandby : null,
		userProfileHandl : null, //refferal to user profile struct
		lastUnfolded : 0,
		rssReaderObj : null,
		feedsAddHdlr: null,//handler for add events dor feed list
		feedsDelHdlr: null,//handler for delete events for feed list
		
		
		constructor: function(args){
     	 //declare.safeMixin(this, args);
    	},
		
		regSinglePodObj : function(podConrtrolHandler) {
			this.podConrtrolHandler = podConrtrolHandler;
		},
		getUserProfileHdl : function() {
			return this.userProfileHandl;
		},
		init_profile  : function(userProfileHdl) {
			var feedsObj = this;
			this.userProfileHandl = userProfileHdl;
			var button = new dijit.form.Button({
				label : "Add RSS channel",
				onClick : function() {
					// Do something:
					var addFeedDlg = dijit.byId("addFeedDialog");
					if(addFeedDlg) {
						dom.byId("feed_url_input").value = "http://";
						addFeedDlg.show();
					}
				},
				id : "addFeedButton"
			}).placeAt("addFeedButtonArea");

			//create somthing like progress bar for add feed operations
			this.addFeedStandby = new dojox.widget.Standby({
				target : "rssPane"
			});
			document.body.appendChild(this.addFeedStandby.domNode);
			this.addFeedStandby.startup();

			this.rssReaderObj = new RssReaderPanel();

		},
		updateUserProfile : function(funShowFunction) {
			var feedsPanObj = this;
			var userProfileHandl = this.userProfileHandl;
			var activPodHandler = this.podConrtrolHandler;
			dojo.xhrGet({
				// The following URL must match that used to test the server.
				url : "./podmanager.cgi",
				handleAs : "json",
				content : {
					rm : "auth_get_user_feeds"
				},
				timeout : 15000, // Time in milliseconds
				// The LOAD function will be called on a successful response.
				load : function(response, ioArgs) {
					userProfileHandl.feeds_list = response.feeds_list;
					userProfileHandl.feeds_title_mapping = response.feeds_title_mapping;
					if(funShowFunction) {
						feedsPanObj.showUserFeeds();
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
		showUserFeeds : function() {
			//var feedItemTmplCont = dojo.cache("", "../templates/feed_item.html");
			var	feedItemTmplCont = dom.byId("feedTemplateField").innerHTML;
			
			var template = new dojox.dtl.Template(feedItemTmplCont);
			var feedsPanObj = this;
			var userProfileHandl = this.userProfileHandl;
			var activPodHandler = this.podConrtrolHandler;
			var podControlObj = this.podConrtrolHandler;
			var rssPanObjHandl = this;
			domConstruct.empty("feedsListPane");
			feedsPanObj.feedsNames = new Array();

			var podFeedsArray = userProfileHandl.pod_info[activPodHandler.getPodId()].pod_feeds;
			dojo.forEach(userProfileHandl.feeds_list, function(feed_id, i) {
				var spodBackColor = "white";
				if((i % 2) > 0) {
					spodBackColor = "#dcdad5";
				} else {
					spodBackColor = "#eee"
				}

				if(dojo.indexOf(podFeedsArray, feed_id) >= 0) {
					var context = new dojox.dtl.Context({
						feed_name : userProfileHandl.feeds_title_mapping[feed_id],
						add_id : "add_feed_" + feed_id,
						del_id : "del_feed_" + feed_id,
						show_add_button : false,
						show_faid : true,
						feed_name_id : "fname_" + feed_id,
						feed_manage_id : "fmanage_" + feed_id
					});
				} else {
					var context = new dojox.dtl.Context({
						feed_name : userProfileHandl.feeds_title_mapping[feed_id],
						add_id : "add_feed_" + feed_id,
						del_id : "del_feed_" + feed_id,
						show_add_button : true,
						show_faid : true,
						feed_name_id : "fname_" + feed_id,
						feed_manage_id : "fmanage_" + feed_id
					});
				}

				var singlePod = domConstruct.create("div", {
					innerHTML : template.render(context),
					id : "feedPane_" + feed_id,
					dojoType : "dijit.layout.ContentPane",
					style : {
						background : spodBackColor
					}
				}, "feedsListPane");

				feedsPanObj.feedsNames[i] = userProfileHandl.feeds_title_mapping[feed_id];

			});
			
			
			
			if(feedsPanObj.feedsDelHdlr){
				feedsPanObj.feedsDelHdlr.remove();
			}
			if(feedsPanObj.feedsAddHdlr){
				feedsPanObj.feedsAddHdlr.remove();
			}
			var feedsList= dom.byId("feedsListPane");
			
			feedsPanObj.feedsDelHdlr = on(feedsList, 
				".del_feed:click", 
				function(evt) {
					
					var feedIndx = this.id.substring("del_feed_".length, this.id.length);
					feedsPanObj.delFeedFromList(feedIndx);
				}
			);
			
			
			feedsPanObj.feedsAddHdlr = on(feedsList, 
				".add_feed:click", 
				function(evt) {
					
					var feedIndx = this.id.substring("add_feed_".length, this.id.length);
					feedsPanObj.addFeedToActivPodcast(feedIndx);
				}
			);
			
			/*dojo.query("[id^='add_feed_']").connect("onclick", function(evt) {
				var feedIndx = evt.currentTarget.id.substring("add_feed_".length, evt.currentTarget.id.length);
				//console.log("FeedIndx " + feedIndx + " evtid " + evt.currentTarget);
				feedsPanObj.addFeedToActivPodcast(feedIndx);
			});

			dojo.query("[id^='del_feed_']").connect("onclick", function(evt) {
				var feedIndx = evt.currentTarget.id.substring("del_feed_".length, evt.currentTarget.id.length);
				//console.log("FeedIndx " + feedIndx + " evtid " + evt.currentTarget);
				feedsPanObj.delFeedFromList(feedIndx);
			});*/
			/* TEMPRORARY DELETE THIS EVENT FROM PRODUCTION
			 * this code show read button but this function is still in development
			 dojo.query("[id^='fname_']").connect("onclick", function(evt){
			 var feedIndx = evt.currentTarget.id.substring("fname_".length, evt.currentTarget.id.length);
			 console.log("FeedIndx " + feedIndx + " evtid " + evt.currentTarget);
			 var feedToManageNodeId = "fmanage_" + feedIndx;
			 feedsPanObj.unfoldFeedManagEls(feedToManageNodeId, feedIndx);
			 });
			 */
		},
		unfoldFeedManagEls : function(feedIndx, feedId) {
			var feedsPanObj = this;

			if(!dojo.hasAttr(feedIndx, "appear")) {
				dojo.attr(feedIndx, "appear", "appear");
				if(feedsPanObj.lastUnfolded != 0) {
					dojo.removeAttr(feedsPanObj.lastUnfolded, "appear");
					var buttonW = dijit.byId("read_rss_button");
					if(buttonW) {
						buttonW.destroy();
					}
				}
				feedsPanObj.lastUnfolded = feedIndx;
				var button = new dijit.form.Button({
					label : "Read RSS cahnnel",
					onClick : function() {
						//var rssReaderObj = new RssReaderPanel();
						feedsPanObj.rssReaderObj.showRssReadWindow(feedId);
					},
					id : "read_rss_button"
				}).placeAt(feedIndx);

			} else {
				feedsPanObj.lastUnfolded = 0;
				dojo.removeAttr(feedIndx, "appear");
				var buttonW = dijit.byId("read_rss_button");
				if(buttonW) {
					buttonW.destroy();
				}
			}

		},
		addNewFeed : function(formAttrs) {
			var feedsPadObj = this;
			this.addFeedStandby.show();
			dojo.xhrGet({
				// The following URL must match that used to test the server.
				url : "./podmanager.cgi",
				handleAs : "text",
				content : {
					rm : "auth_add_feed",
					feed_url : formAttrs.feed_url_input
				},

				timeout : 15000, // Time in milliseconds
				// The LOAD function will be called on a successful response.
				load : function(response, ioArgs) {
					feedsPadObj.addFeedStandby.hide();
					if(response == "ok") {
						feedsPadObj.updateUserProfile(true);
						//feedsPadObj.showUserFeeds();
					} else {
						//fire dialog that we cant do somthing
						if(response == "url_is_not_available") {
							var feedNotFoundDial = dijit.byId("addFeedDialog");
							if(feedNotFoundDial) {
								feedNotFoundDial.show();
							}
							/*
							 var feedNotFoundDial = new dijit.Dialog({
							 title: "Error during feed addition",
							 content: "Sorry, but we can not find RSS channel for this URL.",
							 style: "width: 300px"
							 });
							 feedNotFoundDial.show();*/
						}
					}
					return response;
				},
				// The ERROR function will be called in an error case.
				error : function(response, ioArgs) {
					feedsPadObj.addFeedStandby.hide();
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
		addFeedToActivPodcast : function(feedIdx) {
			var feedsPadObj = this;
			var podControlHandler = this.podConrtrolHandler;
			var podId = podControlHandler.getPodId();
			var userProfileHandl = this.userProfileHandl;

			userProfileHandl.pod_info[podId].pod_feeds.push(feedIdx);
			podControlHandler.showSinglePodData(podId);

			dojo.xhrGet({
				// The following URL must match that used to test the server.
				url : "./podmanager.cgi",
				handleAs : "text",
				content : {
					rm : "auth_add_rss_to_podcast",
					feed_id : feedIdx, //number of feed in user feeds list
					pod_id : podId //number of podcast in user list
				},

				timeout : 5000, // Time in milliseconds
				// The LOAD function will be called on a successful response.
				load : function(response, ioArgs) {
					//dojo.byId("replace").innerHTML = response; //
					if(response == "ok") {
						//do some job
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
		delFeedFromList : function(feedIdx) {
			var feedsPadObj = this;
			//feedsPadObj.addFeedStandby.show();
			var userProfileHandl = this.userProfileHandl;

			var delElIdx = dojo.indexOf(userProfileHandl.feeds_list, feedIdx);
			if(delElIdx >= 0) {
				userProfileHandl.feeds_list.splice(delElIdx, 1);
			}

			feedsPadObj.showUserFeeds();

			dojo.xhrGet({
				// The following URL must match that used to test the server.
				url : "./podmanager.cgi",
				handleAs : "text",
				content : {
					rm : "auth_del_feed_from_user_list",
					feed_id : feedIdx//number of feed in user feeds list
				},

				timeout : 15000, // Time in milliseconds
				// The LOAD function will be called on a successful response.
				load : function(response, ioArgs) {
					//feedsPadObj.addFeedStandby.hide();
					//dojo.byId("replace").innerHTML = response; //
					if(response == "ok") {

						//later this will require
						//podControlHandler.showSinglePodData(podIdInList);
					} else {
						//alert(response);
						//fire dialog that we cant do somthing
					}
					return response;
				},
				// The ERROR function will be called in an error case.
				error : function(response, ioArgs) {
					//feedsPadObj.addFeedStandby.hide();
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

