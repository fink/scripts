//directory > a[@href] == ls path at @id
//package > a[@href] == lspkg contents of a

function ls(elem) {
    $.getJSON("/fdb/index.pl/ls/" + elem.attr("file_id"), function(data) {
	    got_ls(elem, data);
	});
}

function lspkg(elem) {
    $.getJSON("/fdb/index.pl/package/" + elem.attr("package_id"), function(data) {
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
    for(var i = 0; i < data.length; i++) {
	var file = data[i];
	if(file.is_directory) {
	    lschildren += "<li class=\"directory\" " +
		"<a href=\"#\" file_id=\"" + file.file_id +
		"\">" + file.file_name + " (";
	} else {
	    lschildren += "<li>" + file.file_name + " (";
	}

	var packagestr = "";
	var pkgarray = file.packages;
	if(pkgarray.length > 5) {
	    packagestr = "<i>many packages</i>";
	} else {
	    for(var j = 0; j < pkgarray.length; j++) {
		if(j > 0) packagestr += ", ";
		packagestr += pkgarray[j];
	    }
	}

	lschildren += packagestr + ")";
	if(file.is_directory) lschildren += "</a>";
	lschildren += "</li>";
    }
    lschildren += "</ul>";
    node.parent().append(lschildren);
    $(".directory > a[@href]", node.parent()).click(function() { ls($(this)) });
}

function got_lspkg(node, data) {
    node.unbind("click");
    node.click(function() { do_hide(node, "table") });

    var lschildren = "<table>";
    for(var i = 0; i < data.length; i++) {
	var file = data[i];
	lschildren += "<tr>" + 
	    "<td>" + file.flags + "</td>" +
	    "<td>" + file.posix_user + "</td>" +
	    "<td>" + file.posix_group + "</td>" +
	    "<td>" + file.size + "</td>" +
            "<td>" + file.path + "</td></tr>";
    }
    lschildren += "</table>";
    node.parent().append(lschildren);
}

$(function() {
	$(".directory > a[@href]").click(function() { ls($(this)) });
	$(".package > a[@href]").click(function() { lspkg($(this)); });
    });
