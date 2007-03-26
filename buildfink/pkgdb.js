//directory > a[@href] == ls path at @id
//package > a[@href] == lspkg contents of a

function ls(elem) {
    $.getJSON("pkgdb.pl", {op: "ls", dir_id: elem.attr("id")}, function(data) {
	    got_ls(elem, data);
	});
}

function lspkg(elem) {
    $.getJSON("pkgdb.pl", {op: "pkgls", pkg: elem.text()}, function(data) {
	    got_lspkg(elem, data);
	});
}

function do_show(node, child_name) {
    node.unbind("click");
    node.click(function() { do_hide(node, child_name) });
    $(child_name, node.parent()).show();
}

function do_hide(node, child_name) {
    node.unbind("click");
    node.click(function() { do_show(node, child_name) });
    $(child_name, node.parent()).hide();
}

function got_ls(node, data) {
    node.unbind("click");
    node.click(function() { do_hide(node, "ul"); });

    var lschildren = "<ul>";
    $(data).each(function() {
	    if(this["is_directory"]) {
		lschildren += "<li class=\"directory\" " +
		    "<a href=\"#\" id=\"" + this["file_id"] +
		    "\">" + this["name"] + " (";
	    } else {
		lschildren += "<li>" + this["name"] + " (";
	    }

	    var packagestr = "";
	    var pkgarray = this["packages"];
	    for(var i = 0; i < pkgarray.length; i++) {
		if(i > 0) packagestr += ", ";
		packagestr += pkgarray[i];
	    }

	    lschildren += packagestr + ")";
	    if(this["is_directory"]) lschildren += "</a>";
	    lschildren += "</li>";
	});
    lschildren += "</ul>";
    node.parent().append(lschildren);
    $(".directory > a[@href]", node.parent()).click(function() { ls($(this)) });
}

function got_lspkg(node, data) {
    node.unbind("click");
    node.click(function() { do_hide(node, "table") });

    var lschildren = "<table>";
    $(data).each(function() {
	    lschildren += "<tr>" + 
		"<td>" + this["flags"] + "</td>" +
		"<td>" + this["posix_user"] + "</td>" +
		"<td>" + this["posix_group"] + "</td>" +
		"<td>" + this["size"] + "</td>" +
		"<td>" + this["path"] + "</td></tr>";
	});
    lschildren += "</table>";
    node.parent().append(lschildren);
}

$(function() {
	$(".directory > a[@href]").click(function() { ls($(this)) });
	$(".package > a[@href]").click(function() { lspkg($(this)); });
    });