package backend;

import haxe.Json;
import haxe.io.Bytes;
import lime.net.HTTPRequest;
import lime.net.HTTPRequestHeader;

class GitHubAPI
{
	public static inline var API_URL:String = "https://api.github.com";
	public static var token:String = "";

	public static function call(method:String, path:String, ?query:Map<String, String>, ?body:Dynamic, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		var req = new HTTPRequest<String>(buildUrl(path, query));
		req.method = method;
		req.timeout = 15000;
		req.userAgent = "SeiunEngine";
		req.contentType = "application/json";
		req.headers.push(new HTTPRequestHeader("Accept", "application/vnd.github+json"));
		req.headers.push(new HTTPRequestHeader("X-GitHub-Api-Version", "2022-11-28"));

		if (token != null && token.length > 0)
			req.headers.push(new HTTPRequestHeader("Authorization", "Bearer " + token));

		if (body != null)
			req.data = Bytes.ofString(Json.stringify(body));

		req.load().onComplete(function(text:String)
		{
			var status:Int = req.responseStatus;
			if (status >= 200 && status < 300)
			{
				var data:Dynamic = null;
				if (text != null && text.length > 0)
				{
					try
					{
						data = Json.parse(text);
					}
					catch (e:Dynamic)
					{
						if (onError != null) onError("Invalid JSON response");
						return;
					}
				}
				if (onData != null) onData(data);
			}
			else
			{
				if (onError != null) onError("HTTP " + status + " " + (text == null ? "" : text));
			}
		}).onError(function(error:Dynamic)
		{
			if (onError != null) onError(Std.string(error));
		});
	}

	static function buildUrl(path:String, ?query:Map<String, String>):String
	{
		var url:String = API_URL + path;
		if (query != null && query.keys().hasNext())
		{
			var parts:Array<String> = [];
			for (key in query.keys())
			{
				var value:String = query.get(key);
				if (value != null)
					parts.push(StringTools.urlEncode(key) + "=" + StringTools.urlEncode(value));
			}
			if (parts.length > 0)
				url += "?" + parts.join("&");
		}
		return url;
	}

	public static function getRepository(owner:String, repo:String, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		call("GET", "/repos/" + owner + "/" + repo, null, null, onData, onError);
	}

	public static function getLatestRelease(owner:String, repo:String, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		call("GET", "/repos/" + owner + "/" + repo + "/releases/latest", null, null, onData, onError);
	}

	public static function getReleases(owner:String, repo:String, ?perPage:Int = 100, ?page:Int = 1, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		call("GET", "/repos/" + owner + "/" + repo + "/releases", ["per_page" => Std.string(perPage), "page" => Std.string(page)], null, onData, onError);
	}

	public static function getReleaseByTag(owner:String, repo:String, tag:String, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		call("GET", "/repos/" + owner + "/" + repo + "/releases/tags/" + tag, null, null, onData, onError);
	}

	public static function getTags(owner:String, repo:String, ?perPage:Int = 100, ?page:Int = 1, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		call("GET", "/repos/" + owner + "/" + repo + "/tags", ["per_page" => Std.string(perPage), "page" => Std.string(page)], null, onData, onError);
	}

	public static function getBranches(owner:String, repo:String, ?perPage:Int = 100, ?page:Int = 1, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		call("GET", "/repos/" + owner + "/" + repo + "/branches", ["per_page" => Std.string(perPage), "page" => Std.string(page)], null, onData, onError);
	}

	public static function getCommits(owner:String, repo:String, ?branch:String = null, ?perPage:Int = 30, ?page:Int = 1, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		var query:Map<String, String> = ["per_page" => Std.string(perPage), "page" => Std.string(page)];
		if (branch != null && branch.length > 0) query.set("sha", branch);
		call("GET", "/repos/" + owner + "/" + repo + "/commits", query, null, onData, onError);
	}

	public static function getContents(owner:String, repo:String, path:String = "", ?ref:String = null, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		var query:Map<String, String> = null;
		if (ref != null && ref.length > 0) query = ["ref" => ref];
		call("GET", "/repos/" + owner + "/" + repo + "/contents/" + path, query, null, onData, onError);
	}



	public static function getIssues(owner:String, repo:String, ?state:String = "open", ?perPage:Int = 30, ?page:Int = 1, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		call("GET", "/repos/" + owner + "/" + repo + "/issues", ["state" => state, "per_page" => Std.string(perPage), "page" => Std.string(page)], null, onData, onError);
	}

	public static function getIssue(owner:String, repo:String, number:Int, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		call("GET", "/repos/" + owner + "/" + repo + "/issues/" + number, null, null, onData, onError);
	}

	public static function getPullRequests(owner:String, repo:String, ?state:String = "open", ?perPage:Int = 30, ?page:Int = 1, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		call("GET", "/repos/" + owner + "/" + repo + "/pulls", ["state" => state, "per_page" => Std.string(perPage), "page" => Std.string(page)], null, onData, onError);
	}

	public static function getIssueComments(owner:String, repo:String, number:Int, ?perPage:Int = 30, ?page:Int = 1, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		call("GET", "/repos/" + owner + "/" + repo + "/issues/" + number + "/comments", ["per_page" => Std.string(perPage), "page" => Std.string(page)], null, onData, onError);
	}

	public static function createIssue(owner:String, repo:String, title:String, body:String = "", ?labels:Array<String> = null, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		var payload:Dynamic = {title: title, body: body};
		if (labels != null && labels.length > 0) payload.labels = labels;
		call("POST", "/repos/" + owner + "/" + repo + "/issues", null, payload, onData, onError);
	}

	public static function createIssueComment(owner:String, repo:String, number:Int, body:String, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		call("POST", "/repos/" + owner + "/" + repo + "/issues/" + number + "/comments", null, {body: body}, onData, onError);
	}

	public static function updateIssue(owner:String, repo:String, number:Int, ?title:String = null, ?body:String = null, ?state:String = null, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		var payload:Dynamic = {};
		if (title != null) payload.title = title;
		if (body != null) payload.body = body;
		if (state != null) payload.state = state;
		call("PATCH", "/repos/" + owner + "/" + repo + "/issues/" + number, null, payload, onData, onError);
	}

	public static function getUser(username:String, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		call("GET", "/users/" + username, null, null, onData, onError);
	}

	public static function getRateLimit(?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		call("GET", "/rate_limit", null, null, onData, onError);
	}

	public static function searchRepositories(query:String, ?perPage:Int = 30, ?page:Int = 1, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		call("GET", "/search/repositories", ["q" => query, "per_page" => Std.string(perPage), "page" => Std.string(page)], null, onData, onError);
	}

	public static function searchIssues(query:String, ?perPage:Int = 30, ?page:Int = 1, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		call("GET", "/search/issues", ["q" => query, "per_page" => Std.string(perPage), "page" => Std.string(page)], null, onData, onError);
	}

	public static function getRepoLanguages(owner:String, repo:String, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		call("GET", "/repos/" + owner + "/" + repo + "/languages", null, null, onData, onError);
	}

	public static function getContributors(owner:String, repo:String, ?perPage:Int = 30, ?page:Int = 1, ?onData:Dynamic->Void, ?onError:String->Void):Void
	{
		call("GET", "/repos/" + owner + "/" + repo + "/contributors", ["per_page" => Std.string(perPage), "page" => Std.string(page)], null, onData, onError);
	}

	public static function normalizeVersion(version:String):String
	{
		var v:String = StringTools.trim(version);
		if (v.length > 0 && (v.charAt(0) == "v" || v.charAt(0) == "V"))
			v = v.substr(1);
		return v;
	}

	public static function compareVersions(a:String, b:String):Int
	{
		var pa = parseVersion(a);
		var pb = parseVersion(b);

		if (pa.major != pb.major) return pa.major < pb.major ? -1 : 1;
		if (pa.minor != pb.minor) return pa.minor < pb.minor ? -1 : 1;
		if (pa.patch != pb.patch) return pa.patch < pb.patch ? -1 : 1;

		if (pa.pre.length == 0 && pb.pre.length == 0) return 0;
		if (pa.pre.length == 0) return 1;
		if (pb.pre.length == 0) return -1;
		return comparePre(pa.pre, pb.pre);
	}

	static function parseVersion(version:String):{major:Int, minor:Int, patch:Int, pre:Array<String>}
	{
		var v:String = normalizeVersion(version);
		var plus:Int = v.indexOf("+");
		if (plus >= 0) v = v.substr(0, plus);

		var pre:Array<String> = [];
		var dash:Int = v.indexOf("-");
		if (dash >= 0)
		{
			pre = v.substr(dash + 1).split(".");
			v = v.substr(0, dash);
		}

		var parts:Array<String> = v.split(".");
		return {
			major: parts.length > 0 ? parseNum(parts[0]) : 0,
			minor: parts.length > 1 ? parseNum(parts[1]) : 0,
			patch: parts.length > 2 ? parseNum(parts[2]) : 0,
			pre: pre
		};
	}

	static function parseNum(s:String):Int
	{
		var n:Null<Int> = Std.parseInt(s);
		return n == null ? 0 : n;
	}

	static function comparePre(a:Array<String>, b:Array<String>):Int
	{
		var len:Int = a.length > b.length ? a.length : b.length;
		for (i in 0...len)
		{
			if (i >= a.length) return -1;
			if (i >= b.length) return 1;

			var an:Bool = isNumeric(a[i]);
			var bn:Bool = isNumeric(b[i]);

			if (an && bn)
			{
				var d:Int = parseNum(a[i]) - parseNum(b[i]);
				if (d != 0) return d < 0 ? -1 : 1;
			}
			else if (an)
				return -1;
			else if (bn)
				return 1;
			else
			{
				if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
			}
		}
		return 0;
	}

	static function isNumeric(s:String):Bool
	{
		return ~/^[0-9]+$/.match(s);
	}
}
