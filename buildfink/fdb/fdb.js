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

function do_show(node, child_name, show_class, hide_class) {
    node.unbind("click");
    node.click(function() { do_hide(node, child_name, show_class, hide_class) });
    if(show_class) {
	node.parent().removeClass();
	node.parent().addClass(show_class);
    }
    $(child_name, node.parent()).show();
}

function do_hide(node, child_name, show_class, hide_class) {
    node.unbind("click");
    node.click(function() { do_show(node, child_name, show_class, hide_class) });
    if(hide_class) {
	node.parent().removeClass();
	node.parent().addClass(hide_class);
    }
    $(child_name, node.parent()).hide();
}

function got_ls(node, data, show_class, hide_class) {
    do_show(node, "ul", "tree-open", "tree-closed");

    var lschildren = "<ul>";
    for(var i = 0; i < data.length; i++) {
	var file = data[i];
	if(file.is_directory) {
	    lschildren += "<li class=\"tree-closed\" " +
		"<a href=\"javascript:\" file_id=\"" + file.file_id +
		"\">" + file.file_name + " (";
	} else {
	    lschildren += "<li class=\"leaf\" style=\"list-style-image: none\">" + file.file_name + " (";
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
    $("a[@href]", node.parent()).click(function() { ls($(this)) });
}

function got_lspkg(node, data) {
    do_show(node, "table", "tree-open", "tree-closed");

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
	$("#filesystem >> a[@href]").click(function() { ls($(this)) });
	$("#packages >> a[@href]").click(function() { lspkg($(this)); });
	$("#root").click();
    });
