/**
 * @author pozpl
 */

dojo.addOnLoad(function() {
	var as = audiojs.createAll();
	var audio = as[0];
	dojo.query("ol > li > span[data-src]:first-child").forEach(function(node, index, arr) {
		//audio.load(dojo.attr(node, "data-src"));
	});
	//dojo.query("ol.playlist  > li:first-child").addClass("playing");

	dojo.query("ol.playlist > li").connect("onclick", function(evt) {
		dojo.query("ol.playlist > li.playing").removeClass("playing");
		dojo.addClass(evt.currentTarget, "playing");

		dojo.query("> span", evt.currentTarget).forEach(function(node, index, arr) {
			audio.load(dojo.attr(node, "data-src"));
			audio.play();
		});
	});


	soundManager.url = './jslib/soundmanager/';
	soundManager.flashVersion = 9;
	// optional: shiny features (default = 8)
	soundManager.useFlashBlock = false;
	// optionally, enable when you're ready to dive in
	/*
	 * read up on HTML5 audio support, if you're feeling adventurous.
	 * iPad/iPhone and devices without flash installed will always attempt to use it.
	 */
	soundManager.onready(function() {

		// SM2 has loaded - now you can create and play sounds!

		var mySound = soundManager.createSound({
			id : 'aSound',
			url : './media/example.mp3'
			// onload: myOnloadHandler,
			// other options here..
		});

		//mySound.play();

	});
});
