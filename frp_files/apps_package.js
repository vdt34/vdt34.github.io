var liveFlag = location.href.indexOf("www.samsung.com") > -1 ? true : false;
var jsonLandingObj;
var commonObj;

(function () {
	/* xml request start */
	var landingJsonHttp = new XMLHttpRequest(),
		commonJsonHttp = new XMLHttpRequest();

	var	countryCode = typeof APPS_SITE_CODE !== "undefined" ? APPS_SITE_CODE : document.querySelector("meta[name='sitecode']").getAttribute("content"),
		fileName = liveFlag ? "" : "_qa";

	landingJsonHttp.onreadystatechange = function () {
		if (this.readyState === 4 && this.status === 200) {
			jsonLandingObj = JSON.parse(this.responseText);
		}
	}

	commonJsonHttp.onreadystatechange = function () {
		if (this.readyState === 4 && this.status === 200) {
			commonObj = JSON.parse(this.responseText);
		}
	}

	if (typeof APPS_SERVICE_NAME != "undefined" && APPS_SERVICE_NAME == "landing") {
		landingJsonHttp.open("GET", "//images.samsung.com/is/content/samsung/p5/common/apps/json/landing_" + countryCode + fileName + ".json", true);
		landingJsonHttp.send();
	} else {
		commonJsonHttp.open("GET", "//images.samsung.com/is/content/samsung/p5/common/apps/json/common/common_" + countryCode + fileName + ".json", true);
		commonJsonHttp.send();
	}
	/* xml request end */

	;(function(win,doc,callback){'use strict';callback=callback||function(){};function detach(){if(doc.addEventListener){doc.removeEventListener('DOMContentLoaded',completed);}else{doc.detachEvent('onreadystatechange',completed);}}function completed(){if(doc.addEventListener||event.type==='load'||doc.readyState==='complete'){detach();callback(window,window.jQuery);}}function init(){if (doc.addEventListener){doc.addEventListener('DOMContentLoaded',completed);}else{doc.attachEvent('onreadystatechange',completed);}}init();})(window,document,function(win,$){
		
		/* each server(live/QA) append css or js */
		var P5_type = document.getElementById("content").getAttribute("data-type") == "mix" ? "mix" : APPS_SERVICE_NAME == "landing" ? "landing" : "service";
		var P5_jsName = {
			"plugins": {
				"qa": "apps_plugins_qa",
				"live": "apps_plugins"
			},
			"common": {
				"qa": "apps_" + P5_type + "_qa",
				"live": "apps_" + P5_type
			}
		};

		function appendScript(name){
			var jsName = liveFlag ? P5_jsName[name].live : P5_jsName[name].qa;
			var scriptElem = document.createElement("script");
			scriptElem.src = "//images.samsung.com/is/content/samsung/p5/common/apps/js/" + jsName + ".js";
			document.body.appendChild(scriptElem);
		}

		function changeCss() {
			var target = document.getElementsByClassName("apps-css");
			for( var i = 0; i < target.length; i++ ){
				var thisHref = target[i].getAttribute("href");
				var fileName =  thisHref.split("/").pop().split(".")[0];
				var path = thisHref.indexOf("service/") > -1 ? "service/" : "";
				if (fileName.indexOf("_qa") < 0) {
					target[i].setAttribute("href" , "//images.samsung.com/is/content/samsung/p5/common/apps/css/" + path + fileName + "_qa.css" );
				}
			}
		}

		appendScript("plugins");

		if (! liveFlag){
			changeCss();
		} 
		
		var jsLoadCheck = setInterval(function () {
			if (typeof APPS_PLUGIN != "undefined" && APPS_PLUGIN) {
				appendScript("common");
				clearInterval(jsLoadCheck);
			}
		}, 10);
		/* end : each server(live/QA) append css or js */


		/* json mapping */
		if (typeof APPS_JSON_DATA != "undefined") {
			$(".apps, .apps_cr").find("*").each(function () {
				var _this = $(this);

				$.each(this.attributes, function(i, v) {
					if(this.specified) {
						if(v.value.indexOf("{{") > -1 || v.name == "data-ng-bind-html") {
							
							// {{ }} 형식일 경우
							if(v.value.indexOf("{{") > -1) {
								var nonSpaceBracketValue = v.value.replace(/\{|\}/g, '').replace(/^\s+|\s+$/g, ''); // { , } ,공백 제거
								var jsonValueText;

								try {
									jsonValueText = eval("APPS_JSON_DATA." + nonSpaceBracketValue.replace("apps.", "service."));
								} catch(error){
									jsonValueText = "";
								}

								v.value = jsonValueText;
							}

							//data-ng-bind-html 형식일 경우
							if(v.name == "data-ng-bind-html") {
								var nonSpaceValue = v.value.replace(/^\s+|\s+$/g, ''); // 공백 제거
								var jsonHtmlText;

								try {
									jsonHtmlText = eval("APPS_JSON_DATA." + nonSpaceValue.replace("apps.", "service."));
								} catch(error){
									jsonHtmlText = "";
								}

								_this.html(jsonHtmlText);
							}
						}
					}
				});
			});
		}
		/* end : json mapping */

	});

})();