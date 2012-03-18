/**
 * @author pozpl
 */

require(["dojo/dom", 'dojo/query', "dojo/dom-class", "dojo/on","dojo/dom-attr", "dojo/mouse",
"dojo/domReady!"], function(dom, query, domClass, on, domAttr) {

//dojo.addOnLoad(function() {
	var as = audiojs.createAll();
	var audio = as[0];
	query("ol > li > span[data-src]:first-child").forEach(function(node, index, arr) {
		//audio.load(dojo.attr(node, "data-src"));
	});
	//dojo.query("ol.playlist  > li:first-child").addClass("playing");

	query("ol.playlist > li").on("click", function(evt) {
		query("ol.playlist > li.playing").removeClass("playing");
		domClass.add(this, "playing");
		
		query("> span", this).forEach(function(node, index, arr) {
			audio.load(domAttr.get(node, "data-src"));
			audio.play();			
		});
	});

/*
	soundManager.url = './jslib/soundmanager/';
	soundManager.flashVersion = 9;
	soundManager.useFlashBlock = false;
	soundManager.onready(function() {
		var mySound = soundManager.createSound({
			id : 'aSound',
			url : './media/example.mp3'
			// onload: myOnloadHandler,
			// other options here..
		});

		//mySound.play();

	});
*/
});
