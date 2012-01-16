/**
 * @author pozpl
 */
dojo.addOnLoad(function(){
    var as = audiojs.createAll();
    var audio = as[0];
    dojo.query("ol > li > span[data-src]:first-child").forEach(function(node, index, arr){
        //audio.load(dojo.attr(node, "data-src"));
    });
    
    //dojo.query("ol.playlist  > li:first-child").addClass("playing");
    
    dojo.query("ol.playlist > li").connect("onclick", function(evt){
        dojo.query("ol.playlist > li.playing").removeClass("playing");
        dojo.addClass(evt.currentTarget, "playing");		
        
        dojo.query("> span", evt.currentTarget).forEach(function(node, index, arr){
            audio.load(dojo.attr(node, "data-src"));
            audio.play();
        });
    });
    
});
