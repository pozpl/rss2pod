/**
 * @author pozpl
 */
function RssReaderPanel(){

    this.userProfileHandl;
    this.addDownloadStandby;
    this.readerPane;
    
    this.getUserProfileHdl = function(){
        return this.userProfileHandl;
    }
    
    this.showRssReadWindow = function(feedId){
        var feedItemTmplCont = dojo.cache("", "../templates/rss_reader.html");
        var feedTemplate = new dojox.dtl.Template(feedItemTmplCont);
        var context = new dojox.dtl.Context({
            rss_text: "SISI " + feedId,
        });
        
        //widen the midle area to feet
        dijit.byId("podcastsPane").resize({
            w: 0
        });
        dijit.byId("singlePodPane").resize({
            h: 0
        });
        var readerPane = new dijit.layout.ContentPane({
            region: "top",
            style: "height: 95%",
            content: feedTemplate.render(context)
        });
        if (this.readerPane) {
            this.readerPane.destroy();
        }
        this.readerPane = readerPane;
        dijit.byId("borderContainer").addChild(this.readerPane);
        dijit.byId("rssPane").resize();
        var button = new dijit.form.Button({
            label: "Вернуться из режима чтения",
            onClick: function(){
            
            },
            id: "quit_from_read_button"
        }).placeAt("quit_from_read");
    }
}
