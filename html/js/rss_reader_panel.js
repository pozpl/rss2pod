/**
 * @author pozpl
 */

define(["dojo/dom", 'dojo/_base/declare', "dojox/widget/Standby"], function(dom, declare) {
	//require(['dojo/_base/declare'], function(declare) {
	declare("RssReaderPanel", null, {
		//function RssReaderPanel(){

		userProfileHandl : null,
		addDownloadStandby : null,
		readerPane : null,

		getUserProfileHdl : function() {
			return this.userProfileHandl;
		},
		showRssReadWindow : function(feedId) {
			var feedItemTmplCont = dojo.cache("", "../templates/rss_reader.html");
			var feedTemplate = new dojox.dtl.Template(feedItemTmplCont);
			var context = new dojox.dtl.Context({
				rss_text : "SISI " + feedId,
			});

			//widen the midle area to feet
			dijit.byId("podcastsPane").resize({
				w : 0
			});
			dijit.byId("singlePodPane").resize({
				h : 0
			});
			var readerPane = new dijit.layout.ContentPane({
				region : "top",
				style : "height: 95%",
				content : feedTemplate.render(context)
			});
			if(this.readerPane) {
				this.readerPane.destroy();
			}
			this.readerPane = readerPane;
			dijit.byId("borderContainer").addChild(this.readerPane);
			dijit.byId("rssPane").resize();
			var button = new dijit.form.Button({
				label : "Return from reading",
				onClick : function() {

				},
				id : "quit_from_read_button"
			}).placeAt("quit_from_read");
		},
	});
});
