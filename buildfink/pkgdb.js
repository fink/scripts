//directory > a[@href] == ls path at @id
//package > a[@href] == lspkg contents of a

function ls(elem) {
    $.getJSON("pkgdb.pl", {op: "ls", path: elem.attr("id")}, function(data) {
	    got_ls(elem, data);
	});
}

function lspkg(elem) {
    $.getJSON("pkgdb.pl", {op: "pkgls", pkg: elem.text()}, function(data) {
	    got_lspkg(elem, data);
	});
}

function got_ls(node, data) {
    var lschildren = "<ul>";
    $(data.dirs).each(function() {
	    lschildren += "<li class=\"directory\" id=\"" +
		node.attr("id") + "/" + this + "\"><a href=\"#\">" + this + "/</a></li>";
	});
    $(data.dirs).each(function() {
	    lschildren += "<li>" + this + "</li>";
	});
    node.parent().append(lschildren);
    $(",directory > a[@href]", node).click(function() { ls($(this)) });
}

function got_lspkg(node, data) {
    var lschildren = "<ul>";
    $(data).each(function() {
	    lschildren += "<li>" + 
		this["flags"] + " " +
		this["owners"] + " " +
		this["size"] + " " +
		this["path"] + "</li>";
	});
    node.parent().append(lschildren);
}

$(function() {
	$(".directory > a[@href]").click(function() { ls($(this)) });
	$(".package > a[@href]").click(function() { lspkg($(this)); });
    });