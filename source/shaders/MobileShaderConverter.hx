package shaders;

/** Sources prepared for the OpenFL GL program cache and compiler. */
// 参考NF的。。。
typedef MobileShaderProgramSources =
{
	var vertex:String;
	var fragment:String;
	var cacheKey:String;
	var targetVersion:Int;
	var diagnostics:Array<MobileShaderDiagnostic>;
}

typedef MobileShaderDiagnostic =
{
	var stage:String;
	var line:Int;
	var message:String;
}

private typedef MobileShaderStageResult =
{
	var source:String;
	var diagnostics:Array<MobileShaderDiagnostic>;
}

private typedef MobileShaderToken =
{
	var text:String;
	var replacement:Null<String>;
	var prefix:String;
	var suffix:String;
	var kind:Int;
	var line:Int;
	var preprocessor:Bool;
	var removed:Bool;
	var braceDepth:Int;
	var parenDepth:Int;
	var bracketDepth:Int;
}

private typedef MobileShaderOperator =
{
	var start:Int;
	var end:Int;
	var text:String;
	var precedence:Int;
	var rightAssociative:Bool;
	var promotable:Bool;
}

private typedef MobileShaderExpressionRange =
{
	var start:Int;
	var end:Int;
}

private typedef MobileShaderNumericType =
{
	var base:Int;
	var width:Int;
}

private typedef MobileShaderNumericScope =
{
	var parent:Int;
	var start:Int;
	var end:Int;
}

private typedef MobileShaderNumericSymbol =
{
	var name:String;
	var type:MobileShaderNumericType;
	var scope:Int;
	var index:Int;
	var visibleFrom:Int;
	var end:Int;
}

private typedef MobileShaderNumericFunction =
{
	var name:String;
	var returnType:MobileShaderNumericType;
	var parameterTypes:Array<MobileShaderNumericType>;
	var openParen:Int;
	var closeParen:Int;
	var bodyOpen:Int;
	var bodyClose:Int;
}

private typedef MobileShaderNumericMacro =
{
	var name:String;
	var body:MobileShaderExpressionRange;
	var activeFrom:Int;
}

private typedef MobileShaderNumericContext =
{
	var scopeAt:Array<Int>;
	var scopes:Array<MobileShaderNumericScope>;
	var conditionalDepths:Array<Int>;
	var symbols:Array<MobileShaderNumericSymbol>;
	var functions:Map<String, Array<MobileShaderNumericFunction>>;
	var declaredFunctions:Map<String, Bool>;
	var userTypes:Map<String, Bool>;
	var macroNames:Map<String, Bool>;
	var macroTypes:Map<String, MobileShaderNumericType>;
	var macroStarts:Map<String, Int>;
	var macroBodies:Array<MobileShaderNumericMacro>;
	var operators:Array<MobileShaderOperator>;
	var operatorAt:Array<Null<MobileShaderOperator>>;
	var convertiblePreprocessor:Array<Bool>;
	var wrappedRanges:Map<String, Bool>;
}

private typedef MobileShaderGlobalInitializer =
{
	var name:String;
	var equalsIndex:Int;
	var semicolonIndex:Int;
	var expressionStart:Int;
	var line:Int;
}

private typedef MobileShaderEntryPoint =
{
	var nameIndex:Int;
	var conditionalDepth:Int;
}

private typedef MobileShaderEntryPointAnalysis =
{
	var entryPoints:Array<MobileShaderEntryPoint>;
	var ambiguous:Bool;
}

private typedef MobileShaderGlobalInitLowering =
{
	var initializers:Array<MobileShaderGlobalInitializer>;
	var helperNames:Array<String>;
	var guardNames:Array<String>;
}

/**
 * Converts OpenFL's final, pragma-expanded GLSL program to the ESSL version
 * accepted by the current mobile GL context.
 *
 * This is deliberately a strict lexical/declaration converter. It converts
 * syntax only when the target has equivalent semantics. Unsupported desktop
 * features are left visible to the driver and accompanied by precise source
 * diagnostics instead of being approximated into a visually wrong shader.
 */
class MobileShaderConverter
{
	public static inline var ABI_VERSION:Int = 4;

	public static var enabled(default, null):Bool = true;
	public static var revision(default, null):Int = 1;

	private static inline var IDENTIFIER:Int = 0;
	private static inline var NUMBER:Int = 1;
	private static inline var SYMBOL:Int = 2;
	private static inline var WHITESPACE:Int = 3;
	private static inline var COMMENT:Int = 4;
	private static inline var STRING:Int = 5;

	private static inline var NUMERIC_UNKNOWN:Int = 0;
	private static inline var NUMERIC_BOOL:Int = 1;
	private static inline var NUMERIC_INT:Int = 2;
	private static inline var NUMERIC_UINT:Int = 3;
	private static inline var NUMERIC_FLOAT:Int = 4;
	private static inline var NUMERIC_SAMPLER_FLOAT:Int = 5;
	private static inline var NUMERIC_SAMPLER_INT:Int = 6;
	private static inline var NUMERIC_SAMPLER_UINT:Int = 7;

	private static var contextSignature:String = '';
	private static var contextObject:Dynamic;
	private static var contextVersion:Float = 0;
	private static var fragmentHighp:Bool = true;
	private static var extensions:Map<String, Bool> = new Map();

	public static function setEnabled(value:Bool):Void
	{
		if (enabled == value) return;
		enabled = value;
		revision++;
	}

	public static function hasContextCapabilities(version:Float):Bool
	{
		return contextSignature.length > 0 && contextVersion == version;
	}

	public static function setContextCapabilities(version:Float, supportedExtensions:Array<String>, supportsFragmentHighp:Bool):Void
	{
		var normalized:Array<String> = [];
		if (supportedExtensions != null)
		{
			for (extension in supportedExtensions)
			{
				if (extension == null || extension.length == 0) continue;
				var extensionName = normalizeExtensionName(extension);
				if (extensionName.length == 0 || normalized.contains(extensionName)) continue;
				normalized.push(extensionName);
			}
		}
		normalized.sort(function(a:String, b:String):Int return a < b ? -1 : (a > b ? 1 : 0));

		var signature = version + '|' + supportsFragmentHighp + '|' + normalized.join(',');
		if (signature == contextSignature) return;

		contextSignature = signature;
		contextVersion = version;
		fragmentHighp = supportsFragmentHighp;
		extensions = new Map();
		for (extension in normalized)
			extensions.set(extension, true);
		revision++;
	}

	/** Capture capabilities once for the active Lime GL context. */
	public static function configureFromGL(gl:Dynamic):Float
	{
		if (gl == null) return contextVersion > 0 ? contextVersion : 2;
		var glVersion = readContextVersion(gl);
		if (contextObject == gl && hasContextCapabilities(glVersion)) return glVersion;
		var contextChanged = contextObject != gl;
		contextObject = gl;

		var supportedExtensions:Array<String> = [];
		try
		{
			supportedExtensions = gl.getSupportedExtensions();
		}
		catch (_:Dynamic) {}

		var supportsFragmentHighp = glVersion >= 3;
		if (!supportsFragmentHighp)
		{
			try
			{
				var format:Dynamic = gl.getShaderPrecisionFormat(gl.FRAGMENT_SHADER, gl.HIGH_FLOAT);
				supportsFragmentHighp = format != null && format.precision > 0;
			}
			catch (_:Dynamic) {}
		}

		var previousSignature = contextSignature;
		setContextCapabilities(glVersion, supportedExtensions, supportsFragmentHighp);
		// A recreated GL context can expose the same version/extensions but all
		// native Program objects still belong to the old context.
		if (contextChanged && contextSignature == previousSignature) revision++;
		return glVersion;
	}

	private static function readContextVersion(gl:Dynamic):Float
	{
		var result = Math.NaN;
		try
		{
			var value:Dynamic = Reflect.field(gl, 'version');
			if (value != null) result = Std.parseFloat(Std.string(value));
		}
		catch (_:Dynamic) {}

		if (Math.isNaN(result) || result <= 0)
		{
			try
			{
				var versionString = Std.string(gl.getParameter(gl.VERSION));
				var versionPattern = ~/[0-9]+(?:\.[0-9]+)?/;
				if (versionPattern.match(versionString)) result = Std.parseFloat(versionPattern.matched(0));
			}
			catch (_:Dynamic) {}
		}
		return Math.isNaN(result) || result <= 0 ? 2 : result;
	}

	public static function prepareProgram(vertexSource:String, fragmentSource:String, glVersion:Float,
		forceConversion:Bool = false):MobileShaderProgramSources
	{
		if (!enabled && !forceConversion)
		{
			return {
				vertex: vertexSource,
				fragment: fragmentSource,
				cacheKey: 'seiun-glsl-raw-v$ABI_VERSION',
				targetVersion: 0,
				diagnostics: []
			};
		}

		var targetVersion:Int = glVersion >= 3 ? 300 : 100;
		var vertex = convertStage(vertexSource, false, targetVersion);
		var fragment = convertStage(fragmentSource, true, targetVersion);
		var diagnostics = vertex.diagnostics.concat(fragment.diagnostics);

		return {
			vertex: vertex.source,
			fragment: fragment.source,
			cacheKey: 'seiun-glsl-es-$targetVersion-v$ABI_VERSION-hp' + (fragmentHighp ? '1' : '0'),
			targetVersion: targetVersion,
			diagnostics: diagnostics
		};
	}

	private static function convertStage(source:String, isFragment:Bool, targetVersion:Int):MobileShaderStageResult
	{
		if (source == null) source = '';
		source = StringTools.replace(StringTools.replace(source, '\r\n', '\n'), '\r', '\n');
		if (source.length > 0 && StringTools.fastCodeAt(source, 0) == 0xFEFF)
			source = source.substr(1);
		var targetDirective = targetVersion >= 300 ? '#version 300 es\n' : '#version 100\n';
		var convertedMarker = '// SeiunEngine mobile GLSL ABI $ABI_VERSION target $targetVersion\n';
		if (StringTools.startsWith(source, targetDirective + convertedMarker))
			return {source: source, diagnostics: []};

		var stage = isFragment ? 'fragment' : 'vertex';
		var diagnostics:Array<MobileShaderDiagnostic> = [];
		var tokens = tokenize(source);
		assignDepths(tokens);
		var macroNames = collectMacroNames(tokens);
		diagnoseMacroGeneratedGlobalDeclarations(tokens, targetVersion, stage, diagnostics);
		var entryPointAnalysis = collectEntryPoints(tokens);
		var entryPoints = entryPointAnalysis.entryPoints;
		var canWrapEntryPoint = !entryPointAnalysis.ambiguous && entryPoints.length == 1
			&& entryPoints[0].conditionalDepth == 0;
		var globalInitializers = collectGlobalRuntimeInitializers(tokens, macroNames, stage, diagnostics);

		var extensionLines = extractVersionAndExtensions(tokens, targetVersion, stage, diagnostics);
		var generatedHeader:Array<String> = [];
		var generatedFooter:Array<String> = [];

		var es100FragmentOutput:Null<String> = null;
		if (targetVersion >= 300)
			convertToES300(tokens, isFragment, macroNames, generatedHeader, diagnostics);
		else
			es100FragmentOutput = convertToES100(tokens, isFragment, macroNames, extensionLines, generatedHeader,
				canWrapEntryPoint, diagnostics);

		// Desktop GLSL 1.20 permits implicit int-to-float widening in numeric
		// expressions. GLSL ES does not, so preserve the desktop expression tree
		// and insert an explicit conversion only where both operand types can be
		// proven from declarations, constructors, builtins or simple constants.
		widenDesktopNumericExpressions(tokens, macroNames);

		var loweredInitializers = lowerGlobalRuntimeInitializers(tokens, globalInitializers, entryPoints, canWrapEntryPoint,
			stage, diagnostics);
		emitEntryPointWrapper(tokens, entryPoints, canWrapEntryPoint, loweredInitializers, es100FragmentOutput,
			generatedFooter, stage, diagnostics);

		var output = new StringBuf();
		output.add(targetDirective);
		output.add(convertedMarker);
		for (line in extensionLines)
			output.add(line + '\n');

		var precision = targetVersion >= 300 || !isFragment || fragmentHighp ? 'highp' : 'mediump';
		output.add('precision $precision float;\n');
		output.add('precision $precision int;\n');
		output.add('precision lowp sampler2D;\n');
		output.add('precision lowp samplerCube;\n');

		for (line in generatedHeader)
			output.add(line + '\n');

		for (diagnostic in diagnostics)
			output.add('// SeiunEngine ES conversion [${diagnostic.stage}:${diagnostic.line}]: ${sanitizeComment(diagnostic.message)}\n');

		// Keep driver diagnostics aligned with the pragma-expanded input.
		output.add('#line 1\n');
		output.add(render(tokens));
		for (line in generatedFooter)
			output.add(line + '\n');

		return {source: output.toString(), diagnostics: diagnostics};
	}

	private static function collectEntryPoints(tokens:Array<MobileShaderToken>):MobileShaderEntryPointAnalysis
	{
		var result:Array<MobileShaderEntryPoint> = [];
		var ambiguous = false;
		var macroTargets:Map<String, Array<String>> = new Map();
		var macroMayBeUndefined:Map<String, Bool> = new Map();
		var conditionalDepth = 0;

		for (i in 0...tokens.length)
		{
			var token = tokens[i];
			if (token.preprocessor && token.kind == SYMBOL && token.text == '#')
			{
				var directiveIndex = nextSignificantInDirective(tokens, i);
				if (directiveIndex < 0) continue;
				var directive = tokenValue(tokens[directiveIndex]);
				if (directive == 'endif')
				{
					if (conditionalDepth > 0) conditionalDepth--;
					continue;
				}

				if (directive == 'define' || directive == 'undef')
				{
					var nameIndex = nextSignificantInDirective(tokens, directiveIndex);
					if (nameIndex >= 0 && tokens[nameIndex].kind == IDENTIFIER)
					{
						var name = tokenValue(tokens[nameIndex]);
						if (directive == 'undef')
						{
							if (conditionalDepth == 0) macroTargets.remove(name);
							macroMayBeUndefined.set(name, true);
						}
						else
						{
							var bodyIndex = nextSignificantInDirective(tokens, nameIndex);
							var functionLike = bodyIndex >= 0 && bodyIndex == nameIndex + 1
								&& tokenValue(tokens[bodyIndex]) == '(';
							var simpleTarget:Null<String> = null;
							if (!functionLike && bodyIndex >= 0 && tokens[bodyIndex].kind == IDENTIFIER
								&& nextSignificantInDirective(tokens, bodyIndex) < 0)
								simpleTarget = tokenValue(tokens[bodyIndex]);

							if (conditionalDepth == 0)
							{
								if (simpleTarget == null)
									macroTargets.set(name, []);
								else
									macroTargets.set(name, [simpleTarget]);
								macroMayBeUndefined.set(name, false);
							}
							else
							{
								var hadKnownState = macroTargets.exists(name) || macroMayBeUndefined.exists(name);
								if (simpleTarget != null)
								{
									var targets = macroTargets.get(name);
									if (targets == null)
									{
										targets = [];
										macroTargets.set(name, targets);
									}
									if (!targets.contains(simpleTarget)) targets.push(simpleTarget);
								}
								if (!hadKnownState) macroMayBeUndefined.set(name, true);
							}
						}
					}
				}

				if (directive == 'if' || directive == 'ifdef' || directive == 'ifndef') conditionalDepth++;
				continue;
			}

			if (token.removed || token.preprocessor || token.kind != IDENTIFIER
				|| token.braceDepth != 0 || token.parenDepth != 0) continue;
			var returnType = previousSignificant(tokens, i);
			var open = nextSignificant(tokens, i);
			if (returnType < 0 || tokenValue(tokens[returnType]) != 'void' || open < 0 || tokenValue(tokens[open]) != '(') continue;
			var close = findMatching(tokens, open, '(', ')');
			var parameter = close >= 0 ? nextSignificant(tokens, open) : -1;
			if (close < 0 || (parameter != close && (parameter < 0 || tokenValue(tokens[parameter]) != 'void'
				|| nextSignificant(tokens, parameter) != close))) continue;
			var body = close >= 0 ? nextSignificant(tokens, close) : -1;
			if (body < 0 || tokenValue(tokens[body]) != '{'
				|| !canExpandToMain(token.text, macroTargets, macroMayBeUndefined, new Map())) continue;
			if (!expandsOnlyToMain(token.text, macroTargets, macroMayBeUndefined, new Map()))
			{
				ambiguous = true;
				continue;
			}
			result.push({nameIndex: i, conditionalDepth: conditionalDepth});
		}
		return {entryPoints: result, ambiguous: ambiguous};
	}

	private static function canExpandToMain(name:String, macroTargets:Map<String, Array<String>>,
		macroMayBeUndefined:Map<String, Bool>, visiting:Map<String, Bool>):Bool
	{
		if (visiting.exists(name)) return false;
		visiting.set(name, true);
		var targets = macroTargets.get(name);
		var mayRemain = targets == null || macroMayBeUndefined.get(name) == true;
		if (mayRemain && name == 'main') return true;
		if (targets != null)
		{
			for (target in targets)
				if (canExpandToMain(target, macroTargets, macroMayBeUndefined, visiting)) return true;
		}
		visiting.remove(name);
		return false;
	}

	private static function expandsOnlyToMain(name:String, macroTargets:Map<String, Array<String>>,
		macroMayBeUndefined:Map<String, Bool>, visiting:Map<String, Bool>):Bool
	{
		if (visiting.exists(name)) return false;
		visiting.set(name, true);
		var targets = macroTargets.get(name);
		var mayRemain = targets == null || macroMayBeUndefined.get(name) == true;
		if (mayRemain && name != 'main') return false;
		if (!mayRemain && (targets == null || targets.length == 0)) return false;
		if (targets != null)
		{
			for (target in targets)
				if (!expandsOnlyToMain(target, macroTargets, macroMayBeUndefined, visiting)) return false;
		}
		visiting.remove(name);
		return true;
	}

	private static function collectConditionalDepths(tokens:Array<MobileShaderToken>):Array<Int>
	{
		var result = [for (_ in 0...tokens.length) 0];
		var depth = 0;
		for (i in 0...tokens.length)
		{
			var token = tokens[i];
			if (token.preprocessor && token.kind == SYMBOL && token.text == '#')
			{
				var directiveIndex = nextSignificantInDirective(tokens, i);
				var directive = directiveIndex >= 0 ? tokenValue(tokens[directiveIndex]) : '';
				if (directive == 'endif' && depth > 0) depth--;
				result[i] = depth;
				if (directive == 'if' || directive == 'ifdef' || directive == 'ifndef') depth++;
			}
			else
				result[i] = depth;
		}
		return result;
	}

	private static function collectGlobalRuntimeInitializers(tokens:Array<MobileShaderToken>, macroNames:Map<String, Bool>, stage:String,
		diagnostics:Array<MobileShaderDiagnostic>):Array<MobileShaderGlobalInitializer>
	{
		var result:Array<MobileShaderGlobalInitializer> = [];
		var i = 0;
		while (i < tokens.length)
		{
			var token = tokens[i];
			if (token.removed || token.preprocessor || token.kind != SYMBOL || token.text != '='
				|| token.braceDepth != 0 || token.parenDepth != 0 || token.bracketDepth != 0)
			{
				i++;
				continue;
			}

			var previous = previousSignificant(tokens, i);
			var next = nextSignificant(tokens, i);
			if ((previous >= 0 && tokenValue(tokens[previous]) == '=') || (next >= 0 && tokenValue(tokens[next]) == '='))
			{
				i++;
				continue;
			}

			var semicolon = findGlobalStatementEnd(tokens, i);
			if (semicolon < 0) break;
			var conditionalExpression = false;
			for (j in (i + 1)...semicolon)
			{
				if (!tokens[j].preprocessor || tokens[j].kind != SYMBOL || tokens[j].text != '#') continue;
				var directiveIndex = nextSignificantInDirective(tokens, j);
				var directive = directiveIndex >= 0 ? tokenValue(tokens[directiveIndex]) : '';
				if (directive == 'if' || directive == 'ifdef' || directive == 'ifndef' || directive == 'elif'
					|| directive == 'else' || directive == 'endif')
				{
					conditionalExpression = true;
					break;
				}
			}
			if (conditionalExpression)
			{
				addDiagnostic(diagnostics, stage, token.line,
					'Conditional preprocessor branches inside a global initializer cannot be lowered atomically');
				i = semicolon + 1;
				continue;
			}
			var nameIndex = previous;
			var statementStart = findGlobalStatementStart(tokens, i);
			var declarationStarted = false;
			var fragmentedDeclaration = false;
			for (j in statementStart...i)
			{
				var declarationToken = tokens[j];
				if (declarationToken.preprocessor)
				{
					if (declarationToken.kind != SYMBOL || declarationToken.text != '#') continue;
					var directiveIndex = nextSignificantInDirective(tokens, j);
					var directive = directiveIndex >= 0 ? tokenValue(tokens[directiveIndex]) : '';
					if (declarationStarted && (directive == 'if' || directive == 'ifdef' || directive == 'ifndef'
						|| directive == 'elif' || directive == 'else' || directive == 'endif'))
					{
						fragmentedDeclaration = true;
						break;
					}
				}
				else if (!declarationToken.removed && declarationToken.kind != WHITESPACE && declarationToken.kind != COMMENT)
					declarationStarted = true;
			}
			if (fragmentedDeclaration)
			{
				addDiagnostic(diagnostics, stage, token.line,
					'Preprocessor branches that split a global declaration cannot be lowered atomically');
				i = semicolon + 1;
				continue;
			}
			if (nameIndex < statementStart || nameIndex < 0 || tokens[nameIndex].kind != IDENTIFIER)
			{
				var previousValue = nameIndex >= 0 ? tokenValue(tokens[nameIndex]) : '';
				addDiagnostic(diagnostics, stage, token.line, previousValue == ']'
					? 'Global array runtime initializers cannot be lowered exactly on both ES 2 and ES 3'
					: 'Could not parse this global runtime initializer safely');
				i = semicolon + 1;
				continue;
			}

			var declarationIdentifierCount = 0;
			var blockedStorage = false;
			var macroQualifiedDeclaration = false;
			var complexDeclaration = false;
			for (j in statementStart...(nameIndex + 1))
			{
				var declarationToken = tokens[j];
				if (declarationToken.preprocessor || declarationToken.removed) continue;
				var value = tokenValue(declarationToken);
				if (declarationToken.kind == IDENTIFIER)
				{
					if (j < nameIndex && macroNames.exists(declarationToken.text)) macroQualifiedDeclaration = true;
					if (value == 'const' || value == 'uniform' || value == 'attribute' || value == 'varying' || value == 'in'
						|| value == 'buffer' || value == 'shared' || value == 'readonly' || value == 'writeonly') blockedStorage = true;
					if (!isPrecision(value) && value != 'invariant' && value != 'precise' && value != 'centroid'
						&& value != 'flat' && value != 'smooth' && value != 'noperspective' && value != 'layout') declarationIdentifierCount++;
				}
			}
			for (j in statementStart...semicolon)
			{
				var declarationToken = tokens[j];
				if (!declarationToken.preprocessor && !declarationToken.removed && declarationToken.kind == SYMBOL
					&& tokenValue(declarationToken) == ',' && declarationToken.braceDepth == 0
					&& declarationToken.parenDepth == 0 && declarationToken.bracketDepth == 0)
					complexDeclaration = true;
			}

			if (!blockedStorage && declarationIdentifierCount >= 2)
			{
				if (macroQualifiedDeclaration)
				{
					addDiagnostic(diagnostics, stage, token.line,
						'Macro-qualified global declarations cannot be lowered without changing storage semantics');
				}
				else if (complexDeclaration)
				{
					addDiagnostic(diagnostics, stage, token.line,
						'Multiple global declarators with runtime initializers cannot be lowered safely');
				}
				else if (next >= 0 && next < semicolon)
				{
					result.push({
						name: tokenValue(tokens[nameIndex]),
						equalsIndex: i,
						semicolonIndex: semicolon,
						expressionStart: i + 1,
						line: token.line
					});
				}
			}
			i = semicolon + 1;
		}
		return result;
	}

	private static function findGlobalStatementStart(tokens:Array<MobileShaderToken>, index:Int):Int
	{
		var i = index - 1;
		while (i >= 0)
		{
			var token = tokens[i];
			if (!token.preprocessor && token.kind == SYMBOL)
			{
				if (token.text == ';' && token.braceDepth == 0 && token.parenDepth == 0) return i + 1;
				if (token.text == '}' && token.braceDepth == 1 && token.parenDepth == 0) return i + 1;
			}
			i--;
		}
		return 0;
	}

	private static function findGlobalStatementEnd(tokens:Array<MobileShaderToken>, index:Int):Int
	{
		for (i in (index + 1)...tokens.length)
		{
			var token = tokens[i];
			if (!token.preprocessor && !token.removed && token.kind == SYMBOL && token.text == ';'
				&& token.braceDepth == 0 && token.parenDepth == 0 && token.bracketDepth == 0) return i;
		}
		return -1;
	}

	private static function lowerGlobalRuntimeInitializers(tokens:Array<MobileShaderToken>,
		initializers:Array<MobileShaderGlobalInitializer>, entryPoints:Array<MobileShaderEntryPoint>, canWrapEntryPoint:Bool,
		stage:String, diagnostics:Array<MobileShaderDiagnostic>):MobileShaderGlobalInitLowering
	{
		var empty:MobileShaderGlobalInitLowering = {initializers: [], helperNames: [], guardNames: []};
		if (initializers.length == 0) return empty;
		if (!canWrapEntryPoint)
		{
			addDiagnostic(diagnostics, stage, initializers[0].line,
				'Runtime global initializers require one unconditional, unambiguous `main` entry point');
			return empty;
		}

		var lowered:Array<MobileShaderGlobalInitializer> = [];
		var helperNames:Array<String> = [];
		var guardNames:Array<String> = [];
		for (index in 0...initializers.length)
		{
			var initializer = initializers[index];
			var expression = renderRange(tokens, initializer.expressionStart, initializer.semicolonIndex);
			if (StringTools.trim(expression).length == 0) continue;
			var helperName = uniqueIdentifier(tokens, 'seiun_global_init_$index');
			var guardName = uniqueIdentifier(tokens, 'NOVAFLARE_GLOBAL_INIT_$index');

			var definition = new StringBuf();
			definition.add('\nvoid $helperName(void)\n{\n');
			definition.add('#line ${initializer.line}\n');
			definition.add('${initializer.name} =\n');
			definition.add('#line ${initializer.line}\n');
			definition.add(expression);
			if (!StringTools.endsWith(expression, '\n')) definition.add('\n');
			definition.add(';\n}\n');
			definition.add('#define $guardName 1\n');

			var declarationResume = nextSignificant(tokens, initializer.semicolonIndex);
			if (declarationResume >= 0)
			{
				definition.add('#line ${tokens[declarationResume].line}\n');
				tokens[declarationResume].replacement = definition.toString() + tokenValue(tokens[declarationResume]);
			}
			else
				tokens[initializer.semicolonIndex].replacement = tokenValue(tokens[initializer.semicolonIndex]) + definition.toString();

			lowered.push(initializer);
			helperNames.push(helperName);
			guardNames.push(guardName);
		}

		for (initializer in lowered)
			for (i in initializer.equalsIndex...initializer.semicolonIndex)
				tokens[i].removed = true;
		return {initializers: lowered, helperNames: helperNames, guardNames: guardNames};
	}

	private static function emitEntryPointWrapper(tokens:Array<MobileShaderToken>, entryPoints:Array<MobileShaderEntryPoint>,
		canWrapEntryPoint:Bool, lowering:MobileShaderGlobalInitLowering, es100FragmentOutput:Null<String>,
		generatedFooter:Array<String>, stage:String, diagnostics:Array<MobileShaderDiagnostic>):Void
	{
		if (lowering.initializers.length == 0 && es100FragmentOutput == null) return;
		if (!canWrapEntryPoint) return;
		var originalMain = uniqueIdentifier(tokens, 'seiun_original_main');
		if (!renameEntryPoints(tokens, entryPoints, originalMain))
		{
			addDiagnostic(diagnostics, stage, 1, 'Could not wrap the converted `main` entry point safely');
			return;
		}

		generatedFooter.push('');
		// A source macro named `main` must not rewrite the generated canonical entry.
		generatedFooter.push('#undef main');
		generatedFooter.push('void main(void)');
		generatedFooter.push('{');
		for (index in 0...lowering.initializers.length)
		{
			generatedFooter.push('#ifdef ${lowering.guardNames[index]}');
			generatedFooter.push('    ${lowering.helperNames[index]}();');
			generatedFooter.push('#endif');
		}
		generatedFooter.push('    $originalMain();');
		if (es100FragmentOutput != null)
			generatedFooter.push('    gl_FragColor = $es100FragmentOutput;');
		generatedFooter.push('}');
	}

	private static function widenDesktopNumericExpressions(tokens:Array<MobileShaderToken>, macroNames:Map<String, Bool>):Void
	{
		var context = createNumericContext(tokens, macroNames);
		if (context.operators.length == 0) return;

		// Resolve object-like numeric macros before touching expressions. This lets
		// declarations such as `#define TWO_PI (PI * 2)` participate without ever
		// treating function-like macros as typed functions.
		for (_ in 0...4)
		{
			var changed = false;
			for (macroEntry in context.macroBodies)
			{
				var inferred = inferNumericRange(tokens, macroEntry.body.start, macroEntry.body.end,
					macroEntry.body.start, context, 0);
				if (inferred.base != NUMERIC_UNKNOWN && !context.macroTypes.exists(macroEntry.name))
				{
					context.macroTypes.set(macroEntry.name, inferred);
					changed = true;
				}
			}
			if (!changed) break;
		}

		context.operators.sort(function(left, right)
		{
			if (left.precedence != right.precedence) return right.precedence - left.precedence;
			return left.rightAssociative ? right.start - left.start : left.start - right.start;
		});

		for (op in context.operators)
		{
			if (!op.promotable || context.conditionalDepths[op.start] > 0) continue;
			var left = findNumericOperand(tokens, op, true, context);
			var right = findNumericOperand(tokens, op, false, context);
			if (left == null || right == null) continue;

			var leftType = inferNumericRange(tokens, left.start, left.end, op.start, context, 0);
			var rightType = inferNumericRange(tokens, right.start, right.end, op.end, context, 0);
			if (op.text == '=' || op.text == '+=' || op.text == '-='
				|| op.text == '*=' || op.text == '/=')
			{
				if (isFloatNumeric(leftType) && isScalarInteger(rightType))
					wrapNumericRange(tokens, right, context);
				continue;
			}

			if (isFloatNumeric(leftType) && isScalarInteger(rightType))
				wrapNumericRange(tokens, right, context);
			else if (isScalarInteger(leftType) && isFloatNumeric(rightType))
				wrapNumericRange(tokens, left, context);
		}
	}

	private static function createNumericContext(tokens:Array<MobileShaderToken>, macroNames:Map<String, Bool>):MobileShaderNumericContext
	{
		var scopeAt = [for (_ in 0...tokens.length) 0];
		var scopes:Array<MobileShaderNumericScope> = [{parent: -1, start: 0, end: tokens.length}];
		var scopeStack:Array<Int> = [0];
		for (i in 0...tokens.length)
		{
			var token = tokens[i];
			if (!token.preprocessor && !token.removed && token.kind == SYMBOL && tokenValue(token) == '{')
			{
				var child = scopes.length;
				scopes.push({parent: scopeStack[scopeStack.length - 1], start: i, end: tokens.length});
				scopeStack.push(child);
				scopeAt[i] = child;
			}
			else
			{
				scopeAt[i] = scopeStack[scopeStack.length - 1];
				if (!token.preprocessor && !token.removed && token.kind == SYMBOL && tokenValue(token) == '}'
					&& scopeStack.length > 1)
				{
					var closing = scopeStack.pop();
					scopes[closing].end = i;
				}
			}
		}

		var context:MobileShaderNumericContext = {
			scopeAt: scopeAt,
			scopes: scopes,
			conditionalDepths: collectConditionalDepths(tokens),
			symbols: [],
			functions: new Map(),
			declaredFunctions: new Map(),
			userTypes: new Map(),
			macroNames: macroNames,
			macroTypes: new Map(),
			macroStarts: new Map(),
			macroBodies: [],
			operators: [],
			operatorAt: [for (_ in 0...tokens.length) null],
			convertiblePreprocessor: [for (_ in 0...tokens.length) false],
			wrappedRanges: new Map()
		};

		collectNumericUserTypes(tokens, context);
		collectNumericMacros(tokens, macroNames, context);
		collectNumericDeclarations(tokens, context);
		collectNumericOperators(tokens, context);
		return context;
	}

	private static function collectNumericUserTypes(tokens:Array<MobileShaderToken>, context:MobileShaderNumericContext):Void
	{
		for (i in 0...tokens.length)
		{
			var token = tokens[i];
			if (token.removed || token.preprocessor || token.kind != IDENTIFIER || tokenValue(token) != 'struct') continue;
			var nameIndex = nextSignificant(tokens, i);
			if (nameIndex >= 0 && tokens[nameIndex].kind == IDENTIFIER)
				context.userTypes.set(tokenValue(tokens[nameIndex]), true);
		}
	}

	private static function collectNumericMacros(tokens:Array<MobileShaderToken>, macroNames:Map<String, Bool>,
		context:MobileShaderNumericContext):Void
	{
		var definitionCounts:Map<String, Int> = new Map();
		var unsafeNames:Map<String, Bool> = new Map();
		var conditionalDepth = 0;
		for (i in 0...tokens.length)
		{
			if (!tokens[i].preprocessor || tokens[i].kind != SYMBOL || tokenValue(tokens[i]) != '#') continue;
			var directiveIndex = nextSignificantInDirective(tokens, i);
			if (directiveIndex < 0) continue;
			var directiveName = tokenValue(tokens[directiveIndex]);
			if (directiveName == 'endif' && conditionalDepth > 0) conditionalDepth--;
			if (directiveName == 'define' || directiveName == 'undef')
			{
				var macroIndex = nextSignificantInDirective(tokens, directiveIndex);
				if (macroIndex >= 0 && tokens[macroIndex].kind == IDENTIFIER)
				{
					var macroName = tokenValue(tokens[macroIndex]);
					if (directiveName == 'define')
					{
						var count = definitionCounts.exists(macroName) ? definitionCounts.get(macroName) : 0;
						definitionCounts.set(macroName, count + 1);
						if (conditionalDepth > 0 || count > 0) unsafeNames.set(macroName, true);
					}
					else
						unsafeNames.set(macroName, true);
				}
			}
			if (directiveName == 'if' || directiveName == 'ifdef' || directiveName == 'ifndef') conditionalDepth++;
		}

		for (i in 0...tokens.length)
		{
			if (!tokens[i].preprocessor || tokens[i].kind != SYMBOL || tokenValue(tokens[i]) != '#') continue;
			var directive = nextSignificantInDirective(tokens, i);
			if (directive < 0 || tokenValue(tokens[directive]) != 'define') continue;
			var nameIndex = nextSignificantInDirective(tokens, directive);
			if (nameIndex < 0 || tokens[nameIndex].kind != IDENTIFIER || !macroNames.exists(tokens[nameIndex].text)) continue;
			var name = tokens[nameIndex].text;
			if (unsafeNames.exists(name) || definitionCounts.get(name) != 1) continue;
			var bodyStart = nextSignificantInDirective(tokens, nameIndex);
			if (bodyStart < 0) continue;
			// No whitespace between a macro name and `(` means a function-like macro.
			if (bodyStart == nameIndex + 1 && tokenValue(tokens[bodyStart]) == '(') continue;

			var bodyEnd = bodyStart;
			while (bodyEnd + 1 < tokens.length)
			{
				var nextToken = tokens[bodyEnd + 1];
				if (!nextToken.preprocessor) break;
				if (nextToken.kind == WHITESPACE && nextToken.text.indexOf('\n') >= 0)
				{
					var continuation = previousSignificant(tokens, bodyEnd + 1);
					if (continuation < bodyStart || tokenValue(tokens[continuation]) != '\\') break;
				}
				bodyEnd++;
			}
			while (bodyEnd >= bodyStart && (tokens[bodyEnd].kind == WHITESPACE || tokens[bodyEnd].kind == COMMENT)) bodyEnd--;
			if (bodyEnd < bodyStart) continue;
			for (j in bodyStart...(bodyEnd + 1)) context.convertiblePreprocessor[j] = true;
			context.macroStarts.set(name, bodyEnd);
			context.macroBodies.push({name: name, body: {start: bodyStart, end: bodyEnd}, activeFrom: bodyEnd});

			var first = firstNumericSignificant(tokens, bodyStart, bodyEnd);
			var last = lastNumericSignificant(tokens, bodyStart, bodyEnd);
			if (first >= 0 && first == last)
			{
				var directType = numericAtomicType(tokens[first]);
				if (directType.base != NUMERIC_UNKNOWN) context.macroTypes.set(name, directType);
			}
		}
	}

	private static function collectNumericDeclarations(tokens:Array<MobileShaderToken>, context:MobileShaderNumericContext):Void
	{
		var parameterNames:Map<Int, Bool> = new Map();
		for (nameIndex in 0...tokens.length)
		{
			if (tokens[nameIndex].preprocessor || tokens[nameIndex].removed || tokens[nameIndex].kind != IDENTIFIER) continue;
			var open = nextSignificant(tokens, nameIndex);
			if (open < 0 || tokenValue(tokens[open]) != '(') continue;
			var close = findMatching(tokens, open, '(', ')');
			if (close < 0) continue;
			var after = nextSignificant(tokens, close);
			if (after < 0 || (tokenValue(tokens[after]) != '{' && tokenValue(tokens[after]) != ';')) continue;
			var returnIndex = numericFunctionReturnIndex(tokens, nameIndex);
			if (returnIndex < 0 || tokens[returnIndex].kind != IDENTIFIER
				|| isNumericControlKeyword(tokenValue(tokens[returnIndex])) || tokenValue(tokens[returnIndex]) == 'return'
				|| tokenValue(tokens[returnIndex]) == 'case') continue;
			var returnType = numericTypeFromName(tokenValue(tokens[returnIndex]));
			context.declaredFunctions.set(tokenValue(tokens[nameIndex]), true);

			var bodyOpen = tokenValue(tokens[after]) == '{' ? after : -1;
			var bodyClose = bodyOpen >= 0 ? findMatching(tokens, bodyOpen, '{', '}') : -1;
			var parameterTypes:Array<MobileShaderNumericType> = [];
			var parameterStart = nextSignificant(tokens, open);
			while (parameterStart >= 0 && parameterStart < close)
			{
				var comma = findNumericSeparator(tokens, parameterStart, close, ',');
				var parameterEnd = comma >= 0 ? previousSignificant(tokens, comma) : previousSignificant(tokens, close);
				var typeIndex = parameterStart;
				var parameterType = unknownNumericType();
				while (typeIndex >= 0 && typeIndex <= parameterEnd)
				{
					if (tokens[typeIndex].kind == IDENTIFIER)
					{
						var typeName = tokenValue(tokens[typeIndex]);
						parameterType = numericTypeFromName(typeName);
						if (parameterType.base != NUMERIC_UNKNOWN || context.userTypes.exists(typeName)
							|| !isNumericParameterQualifier(typeName)) break;
					}
					typeIndex = nextSignificant(tokens, typeIndex);
				}
				if (typeIndex >= 0 && typeIndex <= parameterEnd)
				{
					var parameterName = nextSignificant(tokens, typeIndex);
					var arrayParameter = false;
					while (parameterName >= 0 && parameterName <= parameterEnd && tokenValue(tokens[parameterName]) == '[')
					{
						arrayParameter = true;
						var arrayClose = findMatching(tokens, parameterName, '[', ']');
						if (arrayClose < 0 || arrayClose > parameterEnd)
						{
							parameterName = -1;
							break;
						}
						parameterName = nextSignificant(tokens, arrayClose);
					}
					while (parameterName >= 0 && parameterName < close && isNumericParameterQualifier(tokenValue(tokens[parameterName])))
						parameterName = nextSignificant(tokens, parameterName);
					var effectiveType = arrayParameter ? unknownNumericType() : parameterType;
					if (parameterName >= 0 && parameterName <= parameterEnd && tokens[parameterName].kind == IDENTIFIER)
					{
						parameterNames.set(parameterName, true);
						var parameterAfter = nextSignificant(tokens, parameterName);
						if (arrayParameter || (parameterAfter >= 0 && parameterAfter <= parameterEnd
							&& tokenValue(tokens[parameterAfter]) == '['))
							effectiveType = unknownNumericType();
						if (context.conditionalDepths[nameIndex] > 0) effectiveType = unknownNumericType();
						if (bodyOpen >= 0)
							context.symbols.push({name: tokenValue(tokens[parameterName]), type: effectiveType,
								scope: context.scopeAt[bodyOpen], index: parameterName,
								visibleFrom: bodyOpen,
								end: bodyClose >= 0 ? bodyClose : context.scopes[context.scopeAt[bodyOpen]].end});
					}
					parameterTypes.push(effectiveType);
				}
				if (comma < 0) break;
				parameterStart = nextSignificant(tokens, comma);
			}

			if (context.conditionalDepths[nameIndex] == 0)
			{
				var overloads = context.functions.get(tokenValue(tokens[nameIndex]));
				if (overloads == null)
				{
					overloads = [];
					context.functions.set(tokenValue(tokens[nameIndex]), overloads);
				}
				overloads.push({name: tokenValue(tokens[nameIndex]), returnType: returnType,
					parameterTypes: parameterTypes, openParen: open, closeParen: close,
					bodyOpen: bodyOpen, bodyClose: bodyClose});
			}
		}

		for (i in 0...tokens.length)
		{
			if (tokens[i].preprocessor || tokens[i].removed || tokens[i].kind != IDENTIFIER) continue;
			var declarationName = tokenValue(tokens[i]);
			var declarationType = numericTypeFromName(declarationName);
			if (declarationType.base == NUMERIC_UNKNOWN && !context.userTypes.exists(declarationName)) continue;
			var nameIndex = nextSignificant(tokens, i);
			if (nameIndex < 0 || tokens[nameIndex].kind != IDENTIFIER || parameterNames.exists(nameIndex)) continue;
			var afterName = nextSignificant(tokens, nameIndex);
			if (afterName >= 0 && tokenValue(tokens[afterName]) == '(') continue;
			var effectiveType = afterName >= 0 && tokenValue(tokens[afterName]) == '['
				|| context.conditionalDepths[nameIndex] > 0 ? unknownNumericType() : declarationType;
			var declarationEnd = numericDeclarationEnd(tokens, nameIndex, context);

			context.symbols.push({name: tokenValue(tokens[nameIndex]), type: effectiveType,
				scope: context.scopeAt[nameIndex], index: nameIndex,
				visibleFrom: numericDeclarationVisibleFrom(tokens, nameIndex),
				end: declarationEnd});
			var separator = nameIndex;
			while (true)
			{
				var comma = findNumericSeparator(tokens, separator, tokens.length, ',');
				var semicolon = findNumericSeparator(tokens, separator, tokens.length, ';');
				if (semicolon < 0 || (comma >= 0 && comma > semicolon) || comma < 0) break;
				var nextName = nextSignificant(tokens, comma);
				if (nextName < 0 || nextName >= semicolon || tokens[nextName].kind != IDENTIFIER) break;
				var nextAfter = nextSignificant(tokens, nextName);
				var nextType = nextAfter >= 0 && tokenValue(tokens[nextAfter]) == '['
					|| context.conditionalDepths[nextName] > 0 ? unknownNumericType() : declarationType;
				context.symbols.push({name: tokenValue(tokens[nextName]), type: nextType,
					scope: context.scopeAt[nextName], index: nextName,
					visibleFrom: numericDeclarationVisibleFrom(tokens, nextName),
					end: declarationEnd});
				separator = nextName;
			}
		}
	}

	private static function numericFunctionReturnIndex(tokens:Array<MobileShaderToken>, nameIndex:Int):Int
	{
		var cursor = previousSignificant(tokens, nameIndex);
		while (cursor >= 0 && tokenValue(tokens[cursor]) == ']')
		{
			var open = findNumericOpening(tokens, cursor, '[', ']');
			if (open < 0) return -1;
			cursor = previousSignificant(tokens, open);
		}
		return cursor;
	}

	private static function numericDeclarationVisibleFrom(tokens:Array<MobileShaderToken>, nameIndex:Int):Int
	{
		var cursor = nextSignificant(tokens, nameIndex);
		while (cursor >= 0 && tokenValue(tokens[cursor]) == '[')
		{
			var close = findMatching(tokens, cursor, '[', ']');
			if (close < 0) return nameIndex;
			cursor = nextSignificant(tokens, close);
		}
		var hasInitializer = cursor >= 0 && tokenValue(tokens[cursor]) == '=';
		var baseBrace = tokens[nameIndex].braceDepth;
		var baseParen = tokens[nameIndex].parenDepth;
		var baseBracket = tokens[nameIndex].bracketDepth;
		var i = cursor;
		while (i >= 0 && i < tokens.length)
		{
			var token = tokens[i];
			if (!token.preprocessor && !token.removed && token.kind == SYMBOL
				&& token.braceDepth == baseBrace && token.parenDepth == baseParen && token.bracketDepth == baseBracket)
			{
				var value = tokenValue(token);
				if (value == ',' || value == ';') return hasInitializer ? i : nameIndex;
			}
			if (!token.preprocessor && (token.braceDepth < baseBrace || token.parenDepth < baseParen
				|| token.bracketDepth < baseBracket)) break;
			i = nextSignificant(tokens, i);
		}
		return nameIndex;
	}

	private static function numericDeclarationEnd(tokens:Array<MobileShaderToken>, nameIndex:Int,
		context:MobileShaderNumericContext):Int
	{
		var defaultEnd = context.scopes[context.scopeAt[nameIndex]].end;
		var statementEnd = numericUnbracedDeclarationEnd(tokens, nameIndex);
		if (statementEnd >= 0) return statementEnd;
		var targetDepth = tokens[nameIndex].parenDepth;
		if (targetDepth <= 0) return defaultEnd;
		var cursor = nameIndex - 1;
		while (cursor >= 0)
		{
			var token = tokens[cursor];
			if (!token.preprocessor && !token.removed && token.kind == SYMBOL && tokenValue(token) == '('
				&& token.parenDepth < targetDepth)
			{
				var close = findMatching(tokens, cursor, '(', ')');
				var before = previousSignificant(tokens, cursor);
				if (close >= nameIndex && before >= 0 && tokenValue(tokens[before]) == 'for')
				{
					var body = nextSignificant(tokens, close);
					if (body < 0) return close;
					if (tokenValue(tokens[body]) == '{')
					{
						var bodyClose = findMatching(tokens, body, '{', '}');
						return bodyClose >= 0 ? bodyClose : defaultEnd;
					}
					var statementEnd = findNumericStatementEnd(tokens, body, defaultEnd + 1);
					return statementEnd >= 0 ? statementEnd : close;
				}
			}
			cursor--;
		}
		return defaultEnd;
	}

	private static function numericUnbracedDeclarationEnd(tokens:Array<MobileShaderToken>, nameIndex:Int):Int
	{
		var declarationStart = previousSignificant(tokens, nameIndex);
		if (declarationStart < 0) return -1;
		var before = previousSignificant(tokens, declarationStart);
		while (before >= 0 && tokens[before].kind == IDENTIFIER && isNumericDeclarationQualifier(tokenValue(tokens[before])))
		{
			declarationStart = before;
			before = previousSignificant(tokens, declarationStart);
		}

		var controlled = before >= 0 && (tokenValue(tokens[before]) == 'else' || tokenValue(tokens[before]) == 'do');
		if (!controlled && before >= 0 && tokenValue(tokens[before]) == ')')
		{
			var open = findNumericOpening(tokens, before, '(', ')');
			var keyword = open >= 0 ? previousSignificant(tokens, open) : -1;
			controlled = keyword >= 0 && (tokenValue(tokens[keyword]) == 'if' || tokenValue(tokens[keyword]) == 'while'
				|| tokenValue(tokens[keyword]) == 'for' || tokenValue(tokens[keyword]) == 'switch');
		}
		if (!controlled) return -1;
		return findNumericSeparator(tokens, nameIndex, tokens.length, ';');
	}

	private static function findNumericStatementEnd(tokens:Array<MobileShaderToken>, start:Int, limit:Int):Int
	{
		start = firstNumericSignificant(tokens, start, limit - 1);
		if (start < 0 || start >= limit) return -1;
		var value = tokenValue(tokens[start]);
		if (value == ';') return start;
		if (value == '{') return findMatching(tokens, start, '{', '}');

		if (value == 'if' || value == 'for' || value == 'while' || value == 'switch')
		{
			var open = nextSignificant(tokens, start);
			if (open < 0 || open >= limit || tokenValue(tokens[open]) != '(') return -1;
			var close = findMatching(tokens, open, '(', ')');
			if (close < 0 || close >= limit) return -1;
			var body = nextSignificant(tokens, close);
			var bodyEnd = body >= 0 && body < limit ? findNumericStatementEnd(tokens, body, limit) : -1;
			if (bodyEnd < 0) return -1;
			if (value == 'if')
			{
				var possibleElse = nextSignificant(tokens, bodyEnd);
				if (possibleElse >= 0 && possibleElse < limit && tokenValue(tokens[possibleElse]) == 'else')
				{
					var elseBody = nextSignificant(tokens, possibleElse);
					if (elseBody < 0 || elseBody >= limit) return -1;
					var elseEnd = findNumericStatementEnd(tokens, elseBody, limit);
					if (elseEnd >= 0) return elseEnd;
				}
			}
			return bodyEnd;
		}

		if (value == 'do')
		{
			var body = nextSignificant(tokens, start);
			var bodyEnd = body >= 0 && body < limit ? findNumericStatementEnd(tokens, body, limit) : -1;
			if (bodyEnd < 0) return -1;
			var whileIndex = nextSignificant(tokens, bodyEnd);
			var open = whileIndex >= 0 && tokenValue(tokens[whileIndex]) == 'while'
				? nextSignificant(tokens, whileIndex) : -1;
			var close = open >= 0 && tokenValue(tokens[open]) == '(' ? findMatching(tokens, open, '(', ')') : -1;
			var semicolon = close >= 0 ? nextSignificant(tokens, close) : -1;
			return semicolon >= 0 && semicolon < limit && tokenValue(tokens[semicolon]) == ';' ? semicolon : bodyEnd;
		}

		return findNumericSeparator(tokens, start, limit, ';');
	}

	private static function findNumericSeparator(tokens:Array<MobileShaderToken>, start:Int, limit:Int, value:String):Int
	{
		var baseBrace = tokens[start].braceDepth;
		var baseParen = tokens[start].parenDepth;
		var baseBracket = tokens[start].bracketDepth;
		var i = start + 1;
		while (i < limit && i < tokens.length)
		{
			var token = tokens[i];
			if (!token.preprocessor && !token.removed && token.kind == SYMBOL
				&& token.braceDepth == baseBrace && token.parenDepth == baseParen && token.bracketDepth == baseBracket
				&& tokenValue(token) == value) return i;
			if (!token.preprocessor && token.braceDepth < baseBrace) break;
			i++;
		}
		return -1;
	}

	private static function collectNumericOperators(tokens:Array<MobileShaderToken>, context:MobileShaderNumericContext):Void
	{
		var i = 0;
		while (i < tokens.length)
		{
			var op = readNumericOperator(tokens, i, context.convertiblePreprocessor);
			if (op == null)
			{
				i++;
				continue;
			}
			context.operators.push(op);
			for (j in op.start...(op.end + 1)) context.operatorAt[j] = op;
			i = op.end + 1;
		}
	}

	private static function readNumericOperator(tokens:Array<MobileShaderToken>, index:Int,
		convertiblePreprocessor:Array<Bool>):Null<MobileShaderOperator>
	{
		var token = tokens[index];
		if (token.removed || token.kind != SYMBOL || (token.preprocessor && !convertiblePreprocessor[index])) return null;
		var first = tokenValue(token);
		var second = index + 1 < tokens.length && tokens[index + 1].kind == SYMBOL
			&& tokens[index + 1].preprocessor == token.preprocessor ? tokenValue(tokens[index + 1]) : '';
		var pair = first + second;
		if (pair == '++' || pair == '--') return null;

		var text = first;
		var end = index;
		var third = index + 2 < tokens.length && tokens[index + 2].kind == SYMBOL
			&& tokens[index + 2].preprocessor == token.preprocessor ? tokenValue(tokens[index + 2]) : '';
		if ((pair == '<<' || pair == '>>') && third == '=')
		{
			text = pair + third;
			end = index + 2;
		}
		else if (pair == '+=' || pair == '-=' || pair == '*=' || pair == '/=' || pair == '%=' || pair == '&='
			|| pair == '|=' || pair == '^=' || pair == '==' || pair == '!='
			|| pair == '<=' || pair == '>=' || pair == '&&' || pair == '||' || pair == '<<' || pair == '>>')
		{
			text = pair;
			end = index + 1;
		}
		else if (first == '=' && index > 0 && tokens[index - 1].kind == SYMBOL
			&& (tokenValue(tokens[index - 1]) == '+' || tokenValue(tokens[index - 1]) == '-'
				|| tokenValue(tokens[index - 1]) == '*' || tokenValue(tokens[index - 1]) == '/'
				|| tokenValue(tokens[index - 1]) == '%' || tokenValue(tokens[index - 1]) == '&'
				|| tokenValue(tokens[index - 1]) == '|' || tokenValue(tokens[index - 1]) == '^' || tokenValue(tokens[index - 1]) == '='
				|| tokenValue(tokens[index - 1]) == '!' || tokenValue(tokens[index - 1]) == '<'
				|| tokenValue(tokens[index - 1]) == '>')) return null;

		var precedence = switch (text)
		{
			case '=', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '<<=', '>>=': 1;
			case '||': 3;
			case '&&': 4;
			case '|': 5;
			case '^': 6;
			case '&': 7;
			case '==', '!=': 8;
			case '<', '<=', '>', '>=': 9;
			case '<<', '>>': 10;
			case '+', '-': 11;
			case '*', '/', '%': 12;
			default: -1;
		};
		if (precedence < 0) return null;
		if ((text == '+' || text == '-') && !numericTokenCanEndExpression(tokens, previousSignificant(tokens, index))) return null;
		var promotable = text == '=' || text == '+=' || text == '-=' || text == '*=' || text == '/='
			|| text == '+' || text == '-' || text == '*' || text == '/'
			|| text == '==' || text == '!=' || text == '<' || text == '<=' || text == '>' || text == '>=';
		return {start: index, end: end, text: text, precedence: precedence,
			rightAssociative: precedence == 1, promotable: promotable};
	}

	private static function numericTokenCanEndExpression(tokens:Array<MobileShaderToken>, index:Int):Bool
	{
		if (index < 0) return false;
		var token = tokens[index];
		if (token.kind == NUMBER) return true;
		if (token.kind == IDENTIFIER)
		{
			var value = tokenValue(token);
			return value != 'return' && value != 'case' && value != 'if' && value != 'while' && value != 'for'
				&& value != 'switch' && value != 'do' && value != 'else' && numericTypeFromName(value).base == NUMERIC_UNKNOWN;
		}
		return token.kind == SYMBOL && (tokenValue(token) == ')' || tokenValue(token) == ']');
	}

	private static inline function isNumericControlKeyword(value:String):Bool
	{
		return value == 'if' || value == 'while' || value == 'for' || value == 'switch';
	}

	private static function findNumericOpening(tokens:Array<MobileShaderToken>, closeIndex:Int, open:String, close:String):Int
	{
		var depth = 0;
		var i = closeIndex;
		while (i >= 0)
		{
			if (!tokens[i].removed && tokens[i].kind == SYMBOL)
			{
				var value = tokenValue(tokens[i]);
				if (value == close) depth++;
				else if (value == open && --depth == 0) return i;
			}
			i--;
		}
		return -1;
	}

	private static function findNumericOperand(tokens:Array<MobileShaderToken>, op:MobileShaderOperator, left:Bool,
		context:MobileShaderNumericContext):Null<MobileShaderExpressionRange>
	{
		var base = tokens[op.start];
		var cursor = left ? previousSignificant(tokens, op.start) : nextSignificant(tokens, op.end);
		if (cursor < 0) return null;
		var start = cursor;
		var end = cursor;

		while (cursor >= 0 && cursor < tokens.length)
		{
			var token = tokens[cursor];
			if (token.removed || token.kind == WHITESPACE || token.kind == COMMENT)
			{
				cursor = left ? previousSignificant(tokens, cursor) : nextSignificant(tokens, cursor);
				continue;
			}
			if (token.preprocessor != base.preprocessor) break;
			if (token.braceDepth < base.braceDepth || token.parenDepth < base.parenDepth
				|| token.bracketDepth < base.bracketDepth) break;
			if (left && !token.preprocessor && token.kind == SYMBOL && tokenValue(token) == ')')
			{
				var open = findNumericOpening(tokens, cursor, '(', ')');
				var beforeOpen = open >= 0 ? previousSignificant(tokens, open) : -1;
				if (beforeOpen >= 0 && tokens[beforeOpen].kind == IDENTIFIER
					&& isNumericControlKeyword(tokenValue(tokens[beforeOpen]))) break;
			}

			var sameLevel = token.braceDepth == base.braceDepth && token.parenDepth == base.parenDepth
				&& token.bracketDepth == base.bracketDepth;
			if (sameLevel)
			{
				var value = tokenValue(token);
				if (value == ';' || value == ',' || value == '{' || value == '}' || value == '?' || value == ':'
					|| value == ')' || value == ']') break;
				if (token.preprocessor && (value == '(' || value == ')')) break;
				var typeStartsCall = token.kind == IDENTIFIER && numericTypeFromName(value).base != NUMERIC_UNKNOWN
					&& nextSignificant(tokens, cursor) >= 0 && tokenValue(tokens[nextSignificant(tokens, cursor)]) == '(';
				if (token.kind == IDENTIFIER && (value == 'return' || value == 'case' || value == 'if' || value == 'while'
					|| value == 'for' || value == 'switch' || value == 'do' || value == 'else'
					|| (numericTypeFromName(value).base != NUMERIC_UNKNOWN && !typeStartsCall))) break;

				var other = context.operatorAt[cursor];
				if (other != null && other.start != op.start)
				{
					var shouldStop = other.precedence < op.precedence
						|| (other.precedence == op.precedence && (left ? op.rightAssociative : !op.rightAssociative));
					if (shouldStop) break;
					cursor = left ? other.start : other.end;
				}
			}

			if (left) start = cursor; else end = cursor;
			cursor = left ? previousSignificant(tokens, cursor) : nextSignificant(tokens, cursor);
		}
		return start <= end ? {start: start, end: end} : null;
	}

	private static function inferNumericRange(tokens:Array<MobileShaderToken>, start:Int, end:Int, useIndex:Int,
		context:MobileShaderNumericContext, depth:Int):MobileShaderNumericType
	{
		if (depth > 48 || start < 0 || end < start || end >= tokens.length) return unknownNumericType();
		start = firstNumericSignificant(tokens, start, end);
		end = lastNumericSignificant(tokens, start, end);
		if (start < 0 || end < start) return unknownNumericType();
		if (context.wrappedRanges.exists(numericRangeKey(start, end))) return floatNumericType(1);

		while (tokenValue(tokens[start]) == '(')
		{
			var close = findMatching(tokens, start, '(', ')');
			if (close != end) break;
			start = firstNumericSignificant(tokens, start + 1, end - 1);
			end = lastNumericSignificant(tokens, start, end - 1);
			if (start < 0 || end < start) return unknownNumericType();
			if (context.wrappedRanges.exists(numericRangeKey(start, end))) return floatNumericType(1);
		}

		var main = findMainNumericOperator(tokens, start, end, context);
		if (main != null)
		{
			var leftEnd = previousSignificant(tokens, main.start);
			var rightStart = nextSignificant(tokens, main.end);
			if (leftEnd < start || rightStart < 0 || rightStart > end) return unknownNumericType();
			var leftType = inferNumericRange(tokens, start, leftEnd, useIndex, context, depth + 1);
			var rightType = inferNumericRange(tokens, rightStart, end, useIndex, context, depth + 1);
			return switch (main.text)
			{
				case '=', '+=', '-=', '*=', '/=', '%=': leftType;
				case '==', '!=', '<', '<=', '>', '>=', '&&', '||': boolNumericType();
				case '%', '<<', '>>', '&', '|', '^': isScalarIntegral(leftType) && isScalarIntegral(rightType)
					? intNumericType() : unknownNumericType();
				case '+', '-', '*', '/': numericArithmeticResult(leftType, rightType);
				default: unknownNumericType();
			};
		}

		var firstValue = tokenValue(tokens[start]);
		if ((firstValue == '+' || firstValue == '-') && start < end)
			return inferNumericRange(tokens, nextSignificant(tokens, start), end, useIndex, context, depth + 1);
		if (firstValue == '!') return boolNumericType();

		if (start == end) return inferNumericAtom(tokens, start, useIndex, context, depth + 1);

		var topDot = -1;
		for (i in start...(end + 1))
		{
			var token = tokens[i];
			if (!token.removed && !token.preprocessor && token.kind == SYMBOL && tokenValue(token) == '.'
				&& token.braceDepth == tokens[start].braceDepth && token.parenDepth == tokens[start].parenDepth
				&& token.bracketDepth == tokens[start].bracketDepth) topDot = i;
		}
		if (topDot >= 0)
		{
			var field = nextSignificant(tokens, topDot);
			if (field == end && tokens[field].kind == IDENTIFIER)
			{
				var owner = inferNumericRange(tokens, start, previousSignificant(tokens, topDot), useIndex, context, depth + 1);
				var width = numericSwizzleWidth(tokenValue(tokens[field]));
				return width > 0 && owner.base != NUMERIC_UNKNOWN ? {base: owner.base, width: width} : unknownNumericType();
			}
		}

		if (tokens[start].kind == IDENTIFIER)
		{
			var open = nextSignificant(tokens, start);
			if (open >= 0 && tokenValue(tokens[open]) == '(')
			{
				var close = findMatching(tokens, open, '(', ')');
				if (close == end) return inferNumericCall(tokens, start, open, close, useIndex, context, depth + 1);
			}
			if (open >= 0 && tokenValue(tokens[open]) == '[')
			{
				var close = findMatching(tokens, open, '[', ']');
				if (close == end)
				{
					var owner = inferNumericAtom(tokens, start, useIndex, context, depth + 1);
					return owner.width > 1 ? {base: owner.base, width: 1} : owner;
				}
			}
		}

		return unknownNumericType();
	}

	private static function findMainNumericOperator(tokens:Array<MobileShaderToken>, start:Int, end:Int,
		context:MobileShaderNumericContext):Null<MobileShaderOperator>
	{
		var first = tokens[start];
		var selected:MobileShaderOperator = null;
		for (op in context.operators)
		{
			if (op.start < start || op.end > end) continue;
			var token = tokens[op.start];
			if (token.braceDepth != first.braceDepth || token.parenDepth != first.parenDepth
				|| token.bracketDepth != first.bracketDepth) continue;
			if (selected == null || op.precedence < selected.precedence
				|| (op.precedence == selected.precedence
					&& (op.rightAssociative ? op.start < selected.start : op.start > selected.start)))
				selected = op;
		}
		return selected;
	}

	private static function inferNumericAtom(tokens:Array<MobileShaderToken>, index:Int, useIndex:Int,
		context:MobileShaderNumericContext, depth:Int):MobileShaderNumericType
	{
		var direct = numericAtomicType(tokens[index]);
		if (direct.base != NUMERIC_UNKNOWN) return direct;
		if (tokens[index].kind != IDENTIFIER) return unknownNumericType();
		var name = tokenValue(tokens[index]);
		var originalName = tokens[index].text;
		if (originalName == 'gl_FragColor' || originalName == 'gl_FragData' || originalName == 'gl_Position' || originalName == 'gl_FragCoord'
			|| originalName == 'gl_PointCoord') return floatNumericType(originalName == 'gl_PointCoord' ? 2 : 4);
		if (originalName == 'gl_PointSize' || originalName == 'gl_FragDepth' || originalName == 'gl_FragDepthEXT')
			return floatNumericType(1);
		if (tokens[index].preprocessor)
		{
			var macroType = activeNumericMacroType(name, useIndex, context);
			return macroType != null ? macroType : unknownNumericType();
		}
		var macroType = activeNumericMacroType(name, useIndex, context);
		if (macroType != null) return macroType;
		if (context.macroNames.exists(name) || context.macroNames.exists(originalName)) return unknownNumericType();
		for (symbol in context.symbols)
			if (symbol.index == index) return symbol.type;
		return resolveNumericSymbol(name, useIndex, context);
	}

	private static function inferNumericCall(tokens:Array<MobileShaderToken>, nameIndex:Int, open:Int, close:Int, useIndex:Int,
		context:MobileShaderNumericContext, depth:Int):MobileShaderNumericType
	{
		var name = tokenValue(tokens[nameIndex]);
		var originalName = tokens[nameIndex].text;
		if (context.macroNames.exists(name) || context.macroNames.exists(originalName)) return unknownNumericType();

		var declaredName:String = null;
		if (context.declaredFunctions.exists(name)) declaredName = name;
		else if (context.declaredFunctions.exists(originalName)) declaredName = originalName;
		if (declaredName != null)
		{
			var declaredOverloads = context.functions.get(declaredName);
			if (declaredOverloads == null || declaredOverloads.length == 0) return unknownNumericType();
			var declaredReturn = declaredOverloads[0].returnType;
			for (candidate in declaredOverloads)
				if (candidate.returnType.base != declaredReturn.base || candidate.returnType.width != declaredReturn.width)
					return unknownNumericType();
			return declaredReturn;
		}

		var constructor = numericTypeFromName(name);
		if (constructor.base != NUMERIC_UNKNOWN) return constructor;
		if (name == 'dot' || name == 'length' || name == 'distance' || name == 'determinant') return floatNumericType(1);
		if (name == 'noise1') return floatNumericType(1);
		if (name == 'noise2') return floatNumericType(2);
		if (name == 'noise3') return floatNumericType(3);
		if (name == 'noise4') return floatNumericType(4);

		var firstArgument = nextSignificant(tokens, open);
		var firstArgumentEnd = firstArgument;
		if (firstArgument >= 0 && firstArgument < close)
		{
			var comma = findNumericSeparator(tokens, firstArgument, close, ',');
			firstArgumentEnd = comma >= 0 ? previousSignificant(tokens, comma) : previousSignificant(tokens, close);
		}
		var firstType = firstArgument >= 0 && firstArgument < close && firstArgumentEnd >= firstArgument
			? inferNumericRange(tokens, firstArgument, firstArgumentEnd, useIndex, context, depth + 1) : unknownNumericType();
		if (originalName == 'texture2D' || originalName == 'textureCube' || originalName == 'texture2DProj'
			|| originalName == 'texture2DLod' || originalName == 'textureCubeLod' || originalName == 'texture2DProjLod'
			|| originalName == 'texture2DLodEXT' || originalName == 'textureCubeLodEXT'
			|| originalName == 'texture2DProjLodEXT'
			|| originalName == 'texture2DGradEXT' || originalName == 'textureCubeGradEXT'
			|| originalName == 'texture2DProjGradEXT')
			return floatNumericType(4);
		if (originalName == 'texture' || originalName == 'textureProj' || originalName == 'textureLod'
			|| originalName == 'textureGrad' || originalName == 'textureProjLod' || originalName == 'textureProjGrad')
		{
			return switch (firstType.base)
			{
				case NUMERIC_SAMPLER_FLOAT: floatNumericType(firstType.width);
				case NUMERIC_SAMPLER_INT: {base: NUMERIC_INT, width: firstType.width};
				case NUMERIC_SAMPLER_UINT: {base: NUMERIC_UINT, width: firstType.width};
				default: unknownNumericType();
			};
		}
		if (name == 'sin' || name == 'cos' || name == 'tan' || name == 'asin' || name == 'acos' || name == 'atan'
			|| name == 'pow' || name == 'exp' || name == 'log' || name == 'exp2' || name == 'log2' || name == 'sqrt'
			|| name == 'inversesqrt' || name == 'abs' || name == 'sign' || name == 'floor' || name == 'ceil'
			|| name == 'fract' || name == 'mod' || name == 'min' || name == 'max' || name == 'clamp' || name == 'mix'
			|| name == 'step' || name == 'smoothstep' || name == 'normalize' || name == 'reflect' || name == 'refract')
			return firstType;

		return unknownNumericType();
	}

	private static function resolveNumericSymbol(name:String, useIndex:Int,
		context:MobileShaderNumericContext):MobileShaderNumericType
	{
		var useScope = useIndex >= 0 && useIndex < context.scopeAt.length ? context.scopeAt[useIndex] : 0;
		var best:MobileShaderNumericSymbol = null;
		var bestDistance = 0x3FFFFFFF;
		for (symbol in context.symbols)
		{
			if (symbol.name != name || symbol.visibleFrom > useIndex || useIndex > symbol.end
				|| !numericScopeContains(symbol.scope, useScope, context.scopes)) continue;
			var distance = numericScopeDistance(symbol.scope, useScope, context.scopes);
			if (best == null || distance < bestDistance || (distance == bestDistance && symbol.index > best.index))
			{
				best = symbol;
				bestDistance = distance;
			}
		}
		return best != null ? best.type : unknownNumericType();
	}

	private static function activeNumericMacroType(name:String, useIndex:Int,
		context:MobileShaderNumericContext):Null<MobileShaderNumericType>
	{
		var type = context.macroTypes.get(name);
		var activeFrom = context.macroStarts.get(name);
		return type != null && activeFrom != null && useIndex > activeFrom ? type : null;
	}

	private static function numericScopeContains(ancestor:Int, child:Int, scopes:Array<MobileShaderNumericScope>):Bool
	{
		var cursor = child;
		while (cursor >= 0)
		{
			if (cursor == ancestor) return true;
			cursor = scopes[cursor].parent;
		}
		return false;
	}

	private static function numericScopeDistance(ancestor:Int, child:Int, scopes:Array<MobileShaderNumericScope>):Int
	{
		var distance = 0;
		var cursor = child;
		while (cursor >= 0 && cursor != ancestor)
		{
			cursor = scopes[cursor].parent;
			distance++;
		}
		return cursor == ancestor ? distance : 0x3FFFFFFF;
	}

	private static function wrapNumericRange(tokens:Array<MobileShaderToken>, range:MobileShaderExpressionRange,
		context:MobileShaderNumericContext):Void
	{
		var start = firstNumericSignificant(tokens, range.start, range.end);
		var end = lastNumericSignificant(tokens, start, range.end);
		if (start < 0 || end < start) return;
		var key = numericRangeKey(start, end);
		if (context.wrappedRanges.exists(key)) return;

		var literalIndex = start;
		if ((tokenValue(tokens[start]) == '+' || tokenValue(tokens[start]) == '-') && start < end)
			literalIndex = nextSignificant(tokens, start);
		if (literalIndex == end && isPlainDecimalInteger(tokens[literalIndex]))
		{
			tokens[literalIndex].replacement = tokenValue(tokens[literalIndex]) + '.0';
		}
		else
		{
			tokens[start].prefix = 'float(' + tokens[start].prefix;
			tokens[end].suffix += ')';
		}
		context.wrappedRanges.set(key, true);
	}

	private static function numericArithmeticResult(left:MobileShaderNumericType,
		right:MobileShaderNumericType):MobileShaderNumericType
	{
		if (left.base == NUMERIC_UNKNOWN || right.base == NUMERIC_UNKNOWN) return unknownNumericType();
		if (left.base == NUMERIC_FLOAT || right.base == NUMERIC_FLOAT)
			return floatNumericType(left.width > right.width ? left.width : right.width);
		if (isScalarIntegral(left) && isScalarIntegral(right))
			return left.base == NUMERIC_UINT || right.base == NUMERIC_UINT ? uintNumericType() : intNumericType();
		return unknownNumericType();
	}

	private static function numericAtomicType(token:MobileShaderToken):MobileShaderNumericType
	{
		if (token.kind == NUMBER)
		{
			var value = tokenValue(token);
			var lower = value.toLowerCase();
			if (StringTools.startsWith(lower, '0x'))
				return StringTools.endsWith(lower, 'u') ? uintNumericType() : intNumericType();
			if (lower.indexOf('.') >= 0 || lower.indexOf('e') >= 0 || StringTools.endsWith(lower, 'f')
				|| StringTools.endsWith(lower, 'lf')) return floatNumericType(1);
			if (StringTools.endsWith(lower, 'u')) return uintNumericType();
			return intNumericType();
		}
		if (token.kind == IDENTIFIER && (tokenValue(token) == 'true' || tokenValue(token) == 'false')) return boolNumericType();
		return unknownNumericType();
	}

	private static function numericTypeFromName(name:String):MobileShaderNumericType
	{
		return switch (name)
		{
			case 'bool': boolNumericType();
			case 'bvec2': {base: NUMERIC_BOOL, width: 2};
			case 'bvec3': {base: NUMERIC_BOOL, width: 3};
			case 'bvec4': {base: NUMERIC_BOOL, width: 4};
			case 'int': intNumericType();
			case 'ivec2': {base: NUMERIC_INT, width: 2};
			case 'ivec3': {base: NUMERIC_INT, width: 3};
			case 'ivec4': {base: NUMERIC_INT, width: 4};
			case 'uint': uintNumericType();
			case 'uvec2': {base: NUMERIC_UINT, width: 2};
			case 'uvec3': {base: NUMERIC_UINT, width: 3};
			case 'uvec4': {base: NUMERIC_UINT, width: 4};
			case 'float', 'double': floatNumericType(1);
			case 'vec2', 'dvec2': floatNumericType(2);
			case 'vec3', 'dvec3': floatNumericType(3);
			case 'vec4', 'dvec4': floatNumericType(4);
			case 'mat2', 'mat2x2', 'dmat2', 'dmat2x2': floatNumericType(4);
			case 'mat3', 'mat3x3', 'dmat3', 'dmat3x3': floatNumericType(9);
			case 'mat4', 'mat4x4', 'dmat4', 'dmat4x4': floatNumericType(16);
			case 'mat2x3', 'mat3x2', 'dmat2x3', 'dmat3x2': floatNumericType(6);
			case 'mat2x4', 'mat4x2', 'dmat2x4', 'dmat4x2': floatNumericType(8);
			case 'mat3x4', 'mat4x3', 'dmat3x4', 'dmat4x3': floatNumericType(12);
			default:
				var lower = name.toLowerCase();
				var width = lower.indexOf('shadow') >= 0 ? 1 : 4;
				if (StringTools.startsWith(lower, 'isampler')) {base: NUMERIC_SAMPLER_INT, width: width};
				else if (StringTools.startsWith(lower, 'usampler')) {base: NUMERIC_SAMPLER_UINT, width: width};
				else if (StringTools.startsWith(lower, 'sampler')) {base: NUMERIC_SAMPLER_FLOAT, width: width};
				else unknownNumericType();
		};
	}

	private static function numericSwizzleWidth(value:String):Int
	{
		if (value.length < 1 || value.length > 4) return 0;
		for (alphabet in ['xyzw', 'rgba', 'stpq'])
		{
			var matches = true;
			for (i in 0...value.length)
				if (alphabet.indexOf(value.charAt(i)) < 0)
				{
					matches = false;
					break;
				}
			if (matches) return value.length;
		}
		return 0;
	}

	private static inline function isNumericParameterQualifier(value:String):Bool
	{
		return value == 'const' || value == 'in' || value == 'out' || value == 'inout'
			|| value == 'lowp' || value == 'mediump' || value == 'highp' || value == 'precise'
			|| value == 'centroid' || value == 'flat' || value == 'smooth' || value == 'noperspective'
			|| value == 'invariant';
	}

	private static inline function isNumericDeclarationQualifier(value:String):Bool
	{
		return isNumericParameterQualifier(value) || value == 'uniform' || value == 'attribute'
			|| value == 'varying' || value == 'buffer' || value == 'shared' || value == 'coherent'
			|| value == 'volatile' || value == 'restrict' || value == 'readonly' || value == 'writeonly';
	}

	private static function firstNumericSignificant(tokens:Array<MobileShaderToken>, start:Int, end:Int):Int
	{
		if (start < 0) start = 0;
		if (end >= tokens.length) end = tokens.length - 1;
		for (i in start...(end + 1))
			if (!tokens[i].removed && tokens[i].kind != WHITESPACE && tokens[i].kind != COMMENT) return i;
		return -1;
	}

	private static function lastNumericSignificant(tokens:Array<MobileShaderToken>, start:Int, end:Int):Int
	{
		if (start < 0 || end < start) return -1;
		if (end >= tokens.length) end = tokens.length - 1;
		var i = end;
		while (i >= start)
		{
			if (!tokens[i].removed && tokens[i].kind != WHITESPACE && tokens[i].kind != COMMENT) return i;
			i--;
		}
		return -1;
	}

	private static inline function isFloatNumeric(type:MobileShaderNumericType):Bool
	{
		return type.base == NUMERIC_FLOAT;
	}

	private static inline function isScalarInteger(type:MobileShaderNumericType):Bool
	{
		return type.width == 1 && type.base == NUMERIC_INT;
	}

	private static inline function isScalarIntegral(type:MobileShaderNumericType):Bool
	{
		return type.width == 1 && (type.base == NUMERIC_INT || type.base == NUMERIC_UINT);
	}

	private static inline function unknownNumericType():MobileShaderNumericType
	{
		return {base: NUMERIC_UNKNOWN, width: 0};
	}

	private static inline function boolNumericType():MobileShaderNumericType
	{
		return {base: NUMERIC_BOOL, width: 1};
	}

	private static inline function intNumericType():MobileShaderNumericType
	{
		return {base: NUMERIC_INT, width: 1};
	}

	private static inline function uintNumericType():MobileShaderNumericType
	{
		return {base: NUMERIC_UINT, width: 1};
	}

	private static inline function floatNumericType(width:Int):MobileShaderNumericType
	{
		return {base: NUMERIC_FLOAT, width: width};
	}

	private static inline function numericRangeKey(start:Int, end:Int):String
	{
		return start + ':' + end;
	}

	private static function isPlainDecimalInteger(token:MobileShaderToken):Bool
	{
		if (token.kind != NUMBER) return false;
		return ~/^(?:0|[1-9][0-9]*)$/.match(tokenValue(token));
	}

	private static function convertToES300(tokens:Array<MobileShaderToken>, isFragment:Bool, macroNames:Map<String, Bool>,
		generatedHeader:Array<String>, diagnostics:Array<MobileShaderDiagnostic>):Void
	{
		diagnoseES300Layouts(tokens, isFragment, diagnostics);
		var fragmentOutputName:String = null;
		var explicitFragmentOutputCount = isFragment ? countGlobalFragmentOutputs(tokens) : 0;
		var hasExplicitFragmentOutput = explicitFragmentOutputCount > 0;
		if (explicitFragmentOutputCount > 1)
			addDiagnostic(diagnostics, 'fragment', 1,
				'OpenFL exposes one color attachment; multiple explicit fragment outputs cannot be preserved');
		var textureMap:Map<String, String> = [
			'texture2D' => 'texture',
			'textureCube' => 'texture',
			'texture2DProj' => 'textureProj',
			'texture2DLod' => 'textureLod',
			'textureCubeLod' => 'textureLod',
			'texture2DProjLod' => 'textureProjLod',
			'texture2DLodEXT' => 'textureLod',
			'textureCubeLodEXT' => 'textureLod',
			'texture2DProjLodEXT' => 'textureProjLod',
			'texture2DGradEXT' => 'textureGrad',
			'textureCubeGradEXT' => 'textureGrad',
			'texture2DProjGradEXT' => 'textureProjGrad'
		];

		for (i in 0...tokens.length)
		{
			var token = tokens[i];
			if (token.removed || token.kind != IDENTIFIER || !canTransform(tokens, i)) continue;

			switch (token.text)
			{
				case 'in', 'out':
					if (token.braceDepth == 0 && token.parenDepth == 0 && isInterfaceBlockQualifier(tokens, i))
						addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', token.line,
							'GLSL ES 3.00 has no shader input/output interface-block equivalent');

				case 'attribute':
					if (isFragment)
						addDiagnostic(diagnostics, 'fragment', token.line, '`attribute` is only valid in a vertex shader');
					else
						token.replacement = 'in';

				case 'varying':
					token.replacement = isFragment ? 'in' : 'out';

				case 'gl_FragColor':
					if (!isFragment)
					{
						addDiagnostic(diagnostics, 'vertex', token.line, '`gl_FragColor` is not available in a vertex shader');
					}
					else if (hasExplicitFragmentOutput)
					{
						addDiagnostic(diagnostics, 'fragment', token.line,
							'Legacy `gl_FragColor` and an explicit fragment output cannot be mixed safely');
					}
					else
					{
						if (fragmentOutputName == null)
							fragmentOutputName = uniqueIdentifier(tokens, 'seiun_FragColor');
						token.replacement = fragmentOutputName;
					}

				case 'gl_FragData':
					if (!isFragment)
						addDiagnostic(diagnostics, 'vertex', token.line, '`gl_FragData` is not available in a vertex shader');
					else if (hasExplicitFragmentOutput)
						addDiagnostic(diagnostics, 'fragment', token.line,
							'Legacy `gl_FragData` and an explicit fragment output cannot be mixed safely');
					else if (isConstantFragDataZero(tokens, i))
					{
						if (fragmentOutputName == null)
							fragmentOutputName = uniqueIdentifier(tokens, 'seiun_FragColor');
						token.replacement = fragmentOutputName;
						removeFragDataZeroIndex(tokens, i);
					}
					else
						addDiagnostic(diagnostics, 'fragment', token.line,
							'OpenFL exposes one color attachment; only constant `gl_FragData[0]` can be converted');

				case 'gl_FragDepthEXT':
					if (isFragment) token.replacement = 'gl_FragDepth';

				case 'noperspective':
					addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', token.line,
						'GLSL ES 3.00 has no core `noperspective` equivalent');

				case 'sampler1D', 'sampler1DShadow', 'sampler2DRect', 'sampler2DRectShadow', 'samplerBuffer', 'sampler2DMS',
					'double', 'dvec2', 'dvec3', 'dvec4', 'dmat2', 'dmat3', 'dmat4':
					addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', token.line,
						'`${token.text}` has no equivalent type in GLSL ES 3.00');

				case 'shadow1D', 'shadow2D', 'shadow1DProj', 'shadow2DProj', 'texture1D', 'texture1DProj', 'texture2DRect':
					addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', token.line,
						'`${token.text}` has no exact GLSL ES 3.00 texture-function equivalent');

				case 'gl_Vertex', 'gl_Normal', 'gl_Color', 'gl_SecondaryColor', 'gl_MultiTexCoord0', 'gl_MultiTexCoord1',
					'gl_MultiTexCoord2', 'gl_MultiTexCoord3', 'gl_MultiTexCoord4', 'gl_MultiTexCoord5', 'gl_MultiTexCoord6',
					'gl_MultiTexCoord7', 'gl_ModelViewMatrix', 'gl_ProjectionMatrix', 'gl_ModelViewProjectionMatrix',
					'gl_NormalMatrix', 'gl_TextureMatrix', 'gl_TexCoord', 'gl_FrontColor', 'gl_BackColor', 'ftransform':
					addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', token.line,
						'Desktop fixed-function builtin `${token.text}` has no automatic OpenFL ES binding');

				default:
					if (textureMap.exists(token.text) && !macroNames.exists(token.text) && isFunctionCall(tokens, i))
						token.replacement = textureMap.get(token.text);
			}
		}

		if (fragmentOutputName != null)
			generatedHeader.push('layout(location = 0) out vec4 $fragmentOutputName;');
	}

	private static function diagnoseES300Layouts(tokens:Array<MobileShaderToken>, isFragment:Bool,
		diagnostics:Array<MobileShaderDiagnostic>):Void
	{
		for (i in 0...tokens.length)
		{
			var token = tokens[i];
			if (token.removed || token.preprocessor || token.kind != IDENTIFIER || token.text != 'layout'
				|| token.braceDepth != 0 || token.parenDepth != 0) continue;
			var open = nextSignificant(tokens, i);
			if (open < 0 || tokenValue(tokens[open]) != '(') continue;
			var close = findMatching(tokens, open, '(', ')');
			var qualifier = close >= 0 ? nextSignificant(tokens, close) : -1;
			if (close < 0 || qualifier < 0) continue;
			var storage = tokenValue(tokens[qualifier]);
			var location = parseLocationLayout(renderRange(tokens, open + 1, close));
			var supported = location != null && ((!isFragment && storage == 'in') || (isFragment && storage == 'out'));
			if (!supported)
				addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', token.line,
					'This desktop `layout(...)` qualifier has no exact GLSL ES 3.00 stage equivalent');
		}
	}

	private static function convertToES100(tokens:Array<MobileShaderToken>, isFragment:Bool, macroNames:Map<String, Bool>,
		extensionLines:Array<String>, generatedHeader:Array<String>, canWrapEntryPoint:Bool,
		diagnostics:Array<MobileShaderDiagnostic>):Null<String>
	{
		removeSafeES100Layouts(tokens, isFragment, diagnostics);

		var usesTexture = false;
		var usesTextureProj = false;
		var usesTextureLod = false;
		var usesTextureGrad = false;
		var usesDerivatives = false;
		var hasLegacyFragmentOutput = isFragment && (containsTransformableIdentifier(tokens, 'gl_FragColor')
			|| containsTransformableIdentifier(tokens, 'gl_FragData'));
		var explicitOutputNames:Array<String> = [];
		var explicitOutputSetUnsafe = false;
		var conditionalDepths = collectConditionalDepths(tokens);
		if (isFragment)
		{
			for (i in 0...tokens.length)
			{
				var token = tokens[i];
				if (token.removed || token.kind != IDENTIFIER || token.text != 'out' || !canTransform(tokens, i)
					|| token.braceDepth != 0 || token.parenDepth != 0
					|| (token.preprocessor && !isStandaloneGlobalStorageMacroToken(tokens, i))) continue;
				if (isInterfaceBlockQualifier(tokens, i))
				{
					explicitOutputSetUnsafe = true;
					continue;
				}
				var declarationIndex = token.preprocessor ? findMacroFragmentOutputUse(tokens, i) : i;
				var output = token.preprocessor ? parseMacroFragmentOutput(tokens, i) : parseSingleFragmentOutput(tokens, i);
				if (declarationIndex < 0 || conditionalDepths[declarationIndex] > 0
					|| (token.preprocessor && conditionalDepths[i] > 0)) explicitOutputSetUnsafe = true;
				if (declarationIndex >= 0)
				{
					var statementStart = findGlobalStatementStart(tokens, declarationIndex);
					for (j in statementStart...declarationIndex)
					{
						var qualifier = tokens[j];
						if (!qualifier.removed && !qualifier.preprocessor && qualifier.kind == IDENTIFIER
							&& macroNames.exists(qualifier.text)) explicitOutputSetUnsafe = true;
					}
				}
				if (output == null)
					explicitOutputSetUnsafe = true;
				else
				{
					if (macroNames.exists(output)) explicitOutputSetUnsafe = true;
					if (!explicitOutputNames.contains(output)) explicitOutputNames.push(output);
				}
			}
		}
		if (explicitOutputNames.length > 1) explicitOutputSetUnsafe = true;
		var explicitFragmentOutput:Null<String> = !hasLegacyFragmentOutput && !explicitOutputSetUnsafe
			&& explicitOutputNames.length == 1 && canWrapEntryPoint ? explicitOutputNames[0] : null;
		var interfacePrecision = fragmentHighp ? 'highp' : 'mediump';
		var textureHelper = uniqueIdentifier(tokens, 'seiun_texture');
		var textureProjHelper = uniqueIdentifier(tokens, 'seiun_textureProj');
		var textureLodHelper = uniqueIdentifier(tokens, 'seiun_textureLod');
		var textureGradHelper = uniqueIdentifier(tokens, 'seiun_textureGrad');

		for (i in 0...tokens.length)
		{
			var token = tokens[i];
			if (token.removed || token.kind != IDENTIFIER || !canTransform(tokens, i)) continue;

			var globalStorageToken = token.braceDepth == 0 && token.parenDepth == 0
				&& (!token.preprocessor || isStandaloneGlobalStorageMacroToken(tokens, i));
			if (globalStorageToken)
			{
				switch (token.text)
				{
					case 'in':
						if (isInterfaceBlockQualifier(tokens, i))
							addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', token.line,
								'GLSL ES 1.00 has no shader input/output interface-block equivalent');
						else
							token.replacement = isFragment ? 'varying' : 'attribute';

					case 'out':
						if (isInterfaceBlockQualifier(tokens, i))
							addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', token.line,
								'GLSL ES 1.00 has no shader input/output interface-block equivalent');
						else if (!isFragment)
							token.replacement = 'varying';
						else
						{
							var output = token.preprocessor ? parseMacroFragmentOutput(tokens, i) : parseSingleFragmentOutput(tokens, i);
							if (hasLegacyFragmentOutput)
								addDiagnostic(diagnostics, 'fragment', token.line,
									'Legacy `gl_FragColor` and an explicit fragment output cannot be mixed safely');
							else if (output == null)
								addDiagnostic(diagnostics, 'fragment', token.line,
									'GLSL ES 1.00 can only lower one top-level `out vec4 name` to `gl_FragColor`');
							else if (!canWrapEntryPoint)
								addDiagnostic(diagnostics, 'fragment', token.line,
									'Explicit fragment output lowering requires one unconditional, unambiguous `main` entry point');
							else if (explicitFragmentOutput == null || explicitFragmentOutput != output)
								addDiagnostic(diagnostics, 'fragment', token.line,
									'OpenFL exposes one color attachment; this fragment output set cannot be converted atomically to ES 2');
							else
							{
								token.replacement = '';
							}
						}

					case 'flat', 'noperspective', 'centroid':
						addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', token.line,
							'`${token.text}` interpolation cannot be represented exactly by GLSL ES 1.00');

					case 'smooth':
						// Smooth interpolation is the ES 2 default.
						token.replacement = '';
				}
			}

			switch (token.text)
			{
				case 'texture':
					if (!macroNames.exists(token.text) && isFunctionCall(tokens, i))
					{
						token.replacement = textureHelper;
						usesTexture = true;
					}

				case 'textureProj':
					if (!macroNames.exists(token.text) && isFunctionCall(tokens, i))
					{
						token.replacement = textureProjHelper;
						usesTextureProj = true;
					}

				case 'textureLod':
					if (!macroNames.exists(token.text) && isFunctionCall(tokens, i))
					{
						token.replacement = textureLodHelper;
						usesTextureLod = true;
					}

				case 'textureGrad':
					if (!macroNames.exists(token.text) && isFunctionCall(tokens, i))
					{
						if (isFragment)
						{
							token.replacement = textureGradHelper;
							usesTextureGrad = true;
						}
						else
							addDiagnostic(diagnostics, 'vertex', token.line,
								'`textureGrad` has no GLSL ES 1.00 vertex-stage equivalent');
					}

				case 'dFdx', 'dFdy', 'fwidth':
					if (isFunctionCall(tokens, i))
					{
						if (isFragment) usesDerivatives = true;
						else addDiagnostic(diagnostics, 'vertex', token.line,
							'Derivative functions have no GLSL ES 1.00 vertex-stage equivalent');
					}

				case 'gl_FragData':
					if (!isFragment)
						addDiagnostic(diagnostics, 'vertex', token.line, '`gl_FragData` is not available in a vertex shader');
					else if (isConstantFragDataZero(tokens, i))
					{
						token.replacement = 'gl_FragColor';
						removeFragDataZeroIndex(tokens, i);
					}
					else
						addDiagnostic(diagnostics, 'fragment', token.line,
							'OpenFL exposes one color attachment; only constant `gl_FragData[0]` can be converted');

				case 'gl_FragDepth':
					if (isFragment)
					{
						if (hasExtension('GL_EXT_frag_depth'))
						{
							token.replacement = 'gl_FragDepthEXT';
							addExtension(extensionLines, '#extension GL_EXT_frag_depth : enable');
						}
						else
							addDiagnostic(diagnostics, 'fragment', token.line,
								'`gl_FragDepth` requires GL_EXT_frag_depth on this ES 2 context');
					}

				case 'gl_FragDepthEXT':
					if (isFragment)
					{
						if (hasExtension('GL_EXT_frag_depth'))
							addExtension(extensionLines, '#extension GL_EXT_frag_depth : enable');
						else
							addDiagnostic(diagnostics, 'fragment', token.line,
								'`gl_FragDepthEXT` requires GL_EXT_frag_depth on this ES 2 context');
					}

				case 'texture2DLodEXT', 'textureCubeLodEXT', 'texture2DProjLodEXT':
					if (isFunctionCall(tokens, i))
					{
						if (!isFragment)
							token.replacement = switch (token.text)
							{
								case 'texture2DLodEXT': 'texture2DLod';
								case 'textureCubeLodEXT': 'textureCubeLod';
								default: 'texture2DProjLod';
							};
						else if (hasExtension('GL_EXT_shader_texture_lod'))
							addExtension(extensionLines, '#extension GL_EXT_shader_texture_lod : enable');
						else
							addDiagnostic(diagnostics, 'fragment', token.line,
								'`${token.text}` requires GL_EXT_shader_texture_lod on this ES 2 context');
					}

				case 'texture2DGradEXT', 'textureCubeGradEXT', 'texture2DProjGradEXT':
					if (isFunctionCall(tokens, i))
					{
						if (!isFragment)
							addDiagnostic(diagnostics, 'vertex', token.line,
								'`${token.text}` has no GLSL ES 1.00 vertex-stage equivalent');
						else if (hasExtension('GL_EXT_shader_texture_lod'))
							addExtension(extensionLines, '#extension GL_EXT_shader_texture_lod : enable');
						else
							addDiagnostic(diagnostics, 'fragment', token.line,
								'`${token.text}` requires GL_EXT_shader_texture_lod on this ES 2 context');
					}

				case 'uint', 'uvec2', 'uvec3', 'uvec4', 'isampler2D', 'isamplerCube', 'usampler2D', 'usamplerCube',
					'sampler2DShadow', 'samplerCubeShadow', 'sampler3D', 'sampler2DArray', 'sampler2DArrayShadow',
					'mat2x3', 'mat2x4', 'mat3x2', 'mat3x4', 'mat4x2', 'mat4x3':
					addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', token.line,
						'`${token.text}` has no exact GLSL ES 1.00 equivalent');

				case 'texelFetch', 'textureSize', 'textureOffset', 'textureProjOffset', 'textureLodOffset', 'textureGradOffset',
					'textureGather', 'bitfieldExtract', 'bitfieldInsert', 'bitCount', 'findLSB', 'findMSB':
					addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', token.line,
						'`${token.text}` cannot be lowered exactly to GLSL ES 1.00');

				case 'switch':
					addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', token.line,
						'`switch` is not available in GLSL ES 1.00');

				case 'gl_Vertex', 'gl_Normal', 'gl_Color', 'gl_SecondaryColor', 'gl_MultiTexCoord0', 'gl_MultiTexCoord1',
					'gl_MultiTexCoord2', 'gl_MultiTexCoord3', 'gl_MultiTexCoord4', 'gl_MultiTexCoord5', 'gl_MultiTexCoord6',
					'gl_MultiTexCoord7', 'gl_ModelViewMatrix', 'gl_ProjectionMatrix', 'gl_ModelViewProjectionMatrix',
					'gl_NormalMatrix', 'gl_TextureMatrix', 'gl_TexCoord', 'gl_FrontColor', 'gl_BackColor', 'ftransform':
					addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', token.line,
						'Desktop fixed-function builtin `${token.text}` has no automatic OpenFL ES binding');
			}
		}

		applyES100VaryingPrecision(tokens, interfacePrecision, diagnostics, isFragment);
		diagnoseES100Operators(tokens, isFragment, diagnostics);

		if (usesDerivatives)
		{
			if (hasExtension('GL_OES_standard_derivatives'))
				addExtension(extensionLines, '#extension GL_OES_standard_derivatives : enable');
			else
				addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', 1,
					'Derivative functions require GL_OES_standard_derivatives on this ES 2 context');
		}

		if (usesTexture)
		{
			generatedHeader.push('vec4 $textureHelper(sampler2D s, vec2 p) { return texture2D(s, p); }');
			generatedHeader.push('vec4 $textureHelper(samplerCube s, vec3 p) { return textureCube(s, p); }');
			if (isFragment)
			{
				generatedHeader.push('vec4 $textureHelper(sampler2D s, vec2 p, float bias) { return texture2D(s, p, bias); }');
				generatedHeader.push('vec4 $textureHelper(samplerCube s, vec3 p, float bias) { return textureCube(s, p, bias); }');
			}
		}

		if (usesTextureProj)
		{
			generatedHeader.push('vec4 $textureProjHelper(sampler2D s, vec3 p) { return texture2DProj(s, p); }');
			generatedHeader.push('vec4 $textureProjHelper(sampler2D s, vec4 p) { return texture2DProj(s, p); }');
			if (isFragment)
			{
				generatedHeader.push('vec4 $textureProjHelper(sampler2D s, vec3 p, float bias) { return texture2DProj(s, p, bias); }');
				generatedHeader.push('vec4 $textureProjHelper(sampler2D s, vec4 p, float bias) { return texture2DProj(s, p, bias); }');
			}
		}

		if (usesTextureLod)
		{
			if (!isFragment)
			{
				generatedHeader.push('vec4 $textureLodHelper(sampler2D s, vec2 p, float lod) { return texture2DLod(s, p, lod); }');
				generatedHeader.push('vec4 $textureLodHelper(samplerCube s, vec3 p, float lod) { return textureCubeLod(s, p, lod); }');
			}
			else if (hasExtension('GL_EXT_shader_texture_lod'))
			{
				addExtension(extensionLines, '#extension GL_EXT_shader_texture_lod : enable');
				generatedHeader.push('vec4 $textureLodHelper(sampler2D s, vec2 p, float lod) { return texture2DLodEXT(s, p, lod); }');
				generatedHeader.push('vec4 $textureLodHelper(samplerCube s, vec3 p, float lod) { return textureCubeLodEXT(s, p, lod); }');
			}
			else
				addDiagnostic(diagnostics, 'fragment', 1,
					'Fragment `textureLod` requires GL_EXT_shader_texture_lod on this ES 2 context');
		}

		if (usesTextureGrad)
		{
			if (hasExtension('GL_EXT_shader_texture_lod'))
			{
				addExtension(extensionLines, '#extension GL_EXT_shader_texture_lod : enable');
				generatedHeader.push('vec4 $textureGradHelper(sampler2D s, vec2 p, vec2 dx, vec2 dy) { return texture2DGradEXT(s, p, dx, dy); }');
				generatedHeader.push('vec4 $textureGradHelper(samplerCube s, vec3 p, vec3 dx, vec3 dy) { return textureCubeGradEXT(s, p, dx, dy); }');
			}
			else
				addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', 1,
					'`textureGrad` requires GL_EXT_shader_texture_lod on this ES 2 context');
		}

		return explicitFragmentOutput;
	}

	private static function removeSafeES100Layouts(tokens:Array<MobileShaderToken>, isFragment:Bool,
		diagnostics:Array<MobileShaderDiagnostic>):Void
	{
		for (i in 0...tokens.length)
		{
			var token = tokens[i];
			if (token.removed || token.preprocessor || token.kind != IDENTIFIER || token.text != 'layout'
				|| token.braceDepth != 0 || token.parenDepth != 0) continue;

			var open = nextSignificant(tokens, i);
			if (open < 0 || tokenValue(tokens[open]) != '(') continue;
			var close = findMatching(tokens, open, '(', ')');
			if (close < 0) continue;
			var qualifierIndex = nextSignificant(tokens, close);
			if (qualifierIndex < 0) continue;
			var qualifier = tokenValue(tokens[qualifierIndex]);
			if (qualifier != 'in' && qualifier != 'out')
			{
				addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', token.line,
					'Only input/output `layout(...)` qualifiers can be lowered to GLSL ES 1.00');
				continue;
			}

			var layoutText = renderRange(tokens, open + 1, close);
			var location = parseLocationLayout(layoutText);
			var safe = location != null && ((!isFragment && qualifier == 'in')
				|| (isFragment && qualifier == 'out' && location == 0));
			if (!safe)
			{
				addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', token.line,
					'Only a vertex attribute location or the single fragment output `location = 0` can be lowered exactly to ES 2');
				continue;
			}

			for (j in i...close + 1)
				tokens[j].removed = true;
		}
	}

	private static function applyES100VaryingPrecision(tokens:Array<MobileShaderToken>, precision:String,
		diagnostics:Array<MobileShaderDiagnostic>, isFragment:Bool):Void
	{
		for (i in 0...tokens.length)
		{
			var token = tokens[i];
			if (token.removed || token.preprocessor || token.braceDepth != 0 || token.parenDepth != 0
				|| tokenValue(token) != 'varying') continue;

			var next = nextSignificant(tokens, i);
			if (next < 0) continue;
			var value = tokenValue(tokens[next]);
			if (value == 'lowp' || value == 'mediump' || value == 'highp')
			{
				if (!fragmentHighp && value == 'highp')
					addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', tokens[next].line,
						'Fragment highp is unavailable; an explicitly highp varying cannot be linked exactly on this ES 2 device');
				continue;
			}
			token.replacement = 'varying $precision';
		}
	}

	private static function parseSingleFragmentOutput(tokens:Array<MobileShaderToken>, outIndex:Int):Null<String>
	{
		var index = nextSignificant(tokens, outIndex);
		while (index >= 0 && isPrecision(tokenValue(tokens[index])))
			index = nextSignificant(tokens, index);
		if (index < 0 || tokenValue(tokens[index]) != 'vec4') return null;

		index = nextSignificant(tokens, index);
		if (index < 0 || tokens[index].kind != IDENTIFIER) return null;
		var name = tokenValue(tokens[index]);

		var end = nextSignificant(tokens, index);
		if (end < 0) return null;
		if (tokenValue(tokens[end]) == '=')
		{
			var semicolon = findGlobalStatementEnd(tokens, end);
			if (semicolon < 0) return null;
			for (i in (end + 1)...semicolon)
			{
				var token = tokens[i];
				if (!token.preprocessor && !token.removed && token.kind == SYMBOL && tokenValue(token) == ','
					&& token.braceDepth == 0 && token.parenDepth == 0 && token.bracketDepth == 0) return null;
			}
		}
		else if (tokenValue(tokens[end]) != ';') return null;
		return name;
	}

	private static function parseMacroFragmentOutput(tokens:Array<MobileShaderToken>, outIndex:Int):Null<String>
	{
		var use = findMacroFragmentOutputUse(tokens, outIndex);
		return use >= 0 ? parseSingleFragmentOutput(tokens, use) : null;
	}

	private static function findMacroFragmentOutputUse(tokens:Array<MobileShaderToken>, outIndex:Int):Int
	{
		var hash = outIndex;
		while (hash >= 0 && tokens[hash].preprocessor)
		{
			if (tokens[hash].kind == SYMBOL && tokens[hash].text == '#') break;
			hash--;
		}
		if (hash < 0 || tokens[hash].text != '#') return -1;
		var directive = nextSignificantInDirective(tokens, hash);
		var nameIndex = directive >= 0 ? nextSignificantInDirective(tokens, directive) : -1;
		if (directive < 0 || tokenValue(tokens[directive]) != 'define' || nameIndex < 0) return -1;
		var name = tokenValue(tokens[nameIndex]);

		var use = -1;
		for (i in 0...tokens.length)
		{
			var token = tokens[i];
			if (token.preprocessor || token.removed || token.kind != IDENTIFIER || token.text != name
				|| token.braceDepth != 0 || token.parenDepth != 0) continue;
			if (use >= 0) return -1;
			use = i;
		}
		return use;
	}

	private static function diagnoseES100Operators(tokens:Array<MobileShaderToken>, isFragment:Bool,
		diagnostics:Array<MobileShaderDiagnostic>):Void
	{
		for (i in 0...tokens.length)
		{
			var token = tokens[i];
			if (token.removed || token.preprocessor || token.kind != SYMBOL) continue;
			var value = tokenValue(token);
			var previous = previousSignificant(tokens, i);
			var next = nextSignificant(tokens, i);
			var previousValue = previous >= 0 ? tokenValue(tokens[previous]) : '';
			var nextValue = next >= 0 ? tokenValue(tokens[next]) : '';
			var unsupported = value == '~' || value == '%'
				|| (value == '&' && previousValue != '&' && nextValue != '&')
				|| (value == '|' && previousValue != '|' && nextValue != '|')
				|| (value == '^' && previousValue != '^' && nextValue != '^')
				|| (value == '<' && nextValue == '<') || (value == '>' && nextValue == '>');
			if (unsupported)
				addDiagnostic(diagnostics, isFragment ? 'fragment' : 'vertex', token.line,
					'Bitwise/integer operator `$value` has no exact GLSL ES 1.00 equivalent');
		}
	}

	private static function renameEntryPoints(tokens:Array<MobileShaderToken>, entryPoints:Array<MobileShaderEntryPoint>,
		replacement:String):Bool
	{
		if (entryPoints.length == 0) return false;
		var renamed = false;
		for (entryPoint in entryPoints)
		{
			var token = tokens[entryPoint.nameIndex];
			if (token.removed || token.preprocessor || token.kind != IDENTIFIER) continue;
			token.replacement = replacement;
			renamed = true;
		}
		return renamed;
	}

	private static function extractVersionAndExtensions(tokens:Array<MobileShaderToken>, targetVersion:Int, stage:String,
		diagnostics:Array<MobileShaderDiagnostic>):Array<String>
	{
		var result:Array<String> = [];
		var i = 0;
		while (i < tokens.length)
		{
			var token = tokens[i];
			if (!token.preprocessor || token.kind != SYMBOL || token.text != '#')
			{
				i++;
				continue;
			}

			var end = i;
			while (end + 1 < tokens.length && tokens[end + 1].line == token.line)
				end++;
			var directive = nextSignificantOnLine(tokens, i, token.line);
			if (directive < 0)
			{
				i = end + 1;
				continue;
			}

			var name = tokenValue(tokens[directive]);
			if (name == 'version' || name == 'extension')
			{
				var directiveText = renderRange(tokens, i, end + 1);
				if (name == 'extension')
				{
					var extensionName = parseExtensionName(directiveText);
					var coreInES300 = extensionName == 'GL_OES_standard_derivatives'
						|| extensionName == 'GL_EXT_shader_texture_lod' || extensionName == 'GL_EXT_frag_depth';
					if (!(targetVersion >= 300 && coreInES300))
					{
						addExtension(result, StringTools.trim(directiveText));
						if (extensionName != null && extensionName != 'all' && !hasExtension(extensionName))
							addDiagnostic(diagnostics, stage, token.line,
								'Requested extension `$extensionName` is not reported by this GL context');
					}
				}

				for (j in i...end + 1)
					if (tokens[j].text.indexOf('\n') < 0)
						tokens[j].removed = true;
			}
			i = end + 1;
		}
		return result;
	}

	private static function diagnoseMacroGeneratedGlobalDeclarations(tokens:Array<MobileShaderToken>, targetVersion:Int,
		stage:String, diagnostics:Array<MobileShaderDiagnostic>):Void
	{
		var suspect:Map<String, Bool> = new Map();
		var functionLikeMacros:Map<String, Bool> = new Map();
		var dependencies:Map<String, Array<String>> = new Map();
		for (i in 0...tokens.length)
		{
			if (!tokens[i].preprocessor || tokens[i].kind != SYMBOL || tokens[i].text != '#') continue;
			var directive = nextSignificantInDirective(tokens, i);
			if (directive < 0 || tokenValue(tokens[directive]) != 'define') continue;
			var nameIndex = nextSignificantInDirective(tokens, directive);
			if (nameIndex < 0 || tokens[nameIndex].kind != IDENTIFIER) continue;
			var name = tokenValue(tokens[nameIndex]);
			var bodyStart = nextSignificantInDirective(tokens, nameIndex);
			if (bodyStart < 0) continue;
			var functionLike = bodyStart == nameIndex + 1 && tokenValue(tokens[bodyStart]) == '(';
			var macroParameters:Array<String> = [];
			if (functionLike)
			{
				functionLikeMacros.set(name, true);
				var close = findMatching(tokens, bodyStart, '(', ')');
				if (close >= 0)
				{
					for (parameterIndex in (bodyStart + 1)...close)
					{
						var parameter = tokens[parameterIndex];
						if (parameter.kind == IDENTIFIER && !macroParameters.contains(parameter.text))
							macroParameters.push(parameter.text);
					}
				}
				bodyStart = close >= 0 ? nextSignificantInDirective(tokens, close) : -1;
				if (bodyStart < 0) continue;
			}

			var significantCount = 0;
			var hasAssignment = false;
			var hasStorage = false;
			var macroDependencies:Array<String> = [];
			var j = bodyStart;
			while (j >= 0 && j < tokens.length && tokens[j].preprocessor)
			{
				var bodyToken = tokens[j];
				if (!bodyToken.removed && bodyToken.kind != WHITESPACE && bodyToken.kind != COMMENT)
				{
					significantCount++;
					var value = tokenValue(bodyToken);
					if (bodyToken.kind == IDENTIFIER && !macroParameters.contains(value)
						&& !macroDependencies.contains(value)) macroDependencies.push(value);
					if (bodyToken.kind == IDENTIFIER && !macroParameters.contains(value)
						&& (targetVersion >= 300 ? (value == 'attribute' || value == 'varying') : (value == 'in' || value == 'out')))
						hasStorage = true;
					if (bodyToken.kind == SYMBOL && value == '=')
					{
						var previous = previousSignificant(tokens, j);
						var next = nextSignificantInDirective(tokens, j);
						var previousValue = previous >= bodyStart ? tokenValue(tokens[previous]) : '';
						var nextValue = next >= 0 ? tokenValue(tokens[next]) : '';
						if (previousValue != '=' && previousValue != '!' && previousValue != '<' && previousValue != '>'
							&& nextValue != '=') hasAssignment = true;
					}
				}
				j++;
			}
			dependencies.set(name, macroDependencies);
			if (hasAssignment || (hasStorage && (functionLike || significantCount > 1))) suspect.set(name, true);
		}

		var changed = true;
		while (changed)
		{
			changed = false;
			for (name => dependencyNames in dependencies)
			{
				if (suspect.exists(name)) continue;
				for (dependency in dependencyNames)
				{
					if (!suspect.exists(dependency)) continue;
					suspect.set(name, true);
					changed = true;
					break;
				}
			}
		}

		for (i in 0...tokens.length)
		{
			var token = tokens[i];
			if (token.removed || token.preprocessor || token.kind != IDENTIFIER || !suspect.exists(token.text)
				|| token.braceDepth != 0 || token.parenDepth != 0 || token.bracketDepth != 0) continue;
			if (functionLikeMacros.exists(token.text))
			{
				var open = nextSignificant(tokens, i);
				if (open < 0 || tokenValue(tokens[open]) != '(') continue;
			}
			var statementStart = findGlobalStatementStart(tokens, i);
			var insideInitializer = false;
			for (j in statementStart...i)
			{
				var prefix = tokens[j];
				if (!prefix.preprocessor && !prefix.removed && prefix.kind == SYMBOL && tokenValue(prefix) == '='
					&& prefix.braceDepth == 0 && prefix.parenDepth == 0 && prefix.bracketDepth == 0)
				{
					insideInitializer = true;
					break;
				}
			}
			if (insideInitializer) continue;
			addDiagnostic(diagnostics, stage, token.line,
				'Macro-generated global declaration bypasses structural lowering; expand it before GLSL ES $targetVersion conversion');
		}
	}

	private static function collectMacroNames(tokens:Array<MobileShaderToken>):Map<String, Bool>
	{
		var result:Map<String, Bool> = new Map();
		for (i in 0...tokens.length)
		{
			if (!tokens[i].preprocessor || tokens[i].kind != SYMBOL || tokens[i].text != '#') continue;
			var directive = nextSignificantInDirective(tokens, i);
			if (directive < 0 || tokenValue(tokens[directive]) != 'define') continue;
			var name = nextSignificantInDirective(tokens, directive);
			if (name >= 0 && tokens[name].kind == IDENTIFIER)
				result.set(tokenValue(tokens[name]), true);
		}
		return result;
	}

	private static function canTransform(tokens:Array<MobileShaderToken>, index:Int):Bool
	{
		var token = tokens[index];
		if (!token.preprocessor) return true;

		var hash = -1;
		var search = index;
		while (search >= 0 && tokens[search].preprocessor)
		{
			if (tokens[search].kind == SYMBOL && tokens[search].text == '#')
			{
				hash = search;
				break;
			}
			search--;
		}
		if (hash < 0) return false;

		var directive = nextSignificantInDirective(tokens, hash);
		if (directive < 0 || tokenValue(tokens[directive]) != 'define') return false;
		var macroName = nextSignificantInDirective(tokens, directive);
		if (macroName < 0 || index <= macroName) return false;

		var next = nextSignificantInDirective(tokens, macroName);
		if (next == macroName + 1 && tokenValue(tokens[next]) == '(')
		{
			var close = findMatching(tokens, next, '(', ')');
			return close >= 0 && index > close;
		}
		return index > macroName;
	}

	/**
	 * `in` and `out` are also legal function-parameter qualifiers in ES 1.00.
	 * Only rewrite them inside a macro when the replacement is exactly that
	 * one token and every real use of the macro is at global declaration scope.
	 */
	private static function isStandaloneGlobalStorageMacroToken(tokens:Array<MobileShaderToken>, index:Int):Bool
	{
		var hash = index;
		while (hash >= 0 && tokens[hash].preprocessor)
		{
			if (tokens[hash].kind == SYMBOL && tokens[hash].text == '#') break;
			hash--;
		}
		if (hash < 0 || tokens[hash].text != '#') return false;

		var directive = nextSignificantInDirective(tokens, hash);
		var macroName = directive >= 0 ? nextSignificantInDirective(tokens, directive) : -1;
		if (directive < 0 || tokenValue(tokens[directive]) != 'define' || macroName < 0) return false;

		var bodyStart = nextSignificantInDirective(tokens, macroName);
		if (bodyStart == macroName + 1 && bodyStart >= 0 && tokenValue(tokens[bodyStart]) == '(')
		{
			var close = findMatching(tokens, bodyStart, '(', ')');
			bodyStart = close >= 0 ? nextSignificantInDirective(tokens, close) : -1;
		}
		if (bodyStart != index) return false;

		var after = nextSignificantInDirective(tokens, index);
		while (after >= 0 && tokenValue(tokens[after]) == '\\')
			after = nextSignificantInDirective(tokens, after);
		if (after >= 0) return false;

		var name = tokenValue(tokens[macroName]);
		var foundUse = false;
		for (token in tokens)
		{
			if (token.preprocessor || token.removed || token.kind != IDENTIFIER || token.text != name) continue;
			foundUse = true;
			if (token.braceDepth != 0 || token.parenDepth != 0) return false;
		}
		return foundUse;
	}

	private static function isFunctionCall(tokens:Array<MobileShaderToken>, index:Int):Bool
	{
		var next = nextSignificant(tokens, index);
		if (next < 0 || tokenValue(tokens[next]) != '(') return false;
		var previous = previousSignificant(tokens, index);
		return previous < 0 || tokenValue(tokens[previous]) != '.';
	}

	private static function isConstantFragDataZero(tokens:Array<MobileShaderToken>, index:Int):Bool
	{
		var open = nextSignificant(tokens, index);
		var value = open >= 0 ? nextSignificant(tokens, open) : -1;
		var close = value >= 0 ? nextSignificant(tokens, value) : -1;
		return open >= 0 && value >= 0 && close >= 0 && tokenValue(tokens[open]) == '['
			&& tokenValue(tokens[value]) == '0' && tokenValue(tokens[close]) == ']';
	}

	private static function removeFragDataZeroIndex(tokens:Array<MobileShaderToken>, index:Int):Void
	{
		var open = nextSignificant(tokens, index);
		var value = nextSignificant(tokens, open);
		var close = nextSignificant(tokens, value);
		for (i in open...close + 1) tokens[i].removed = true;
	}

	private static function uniqueIdentifier(tokens:Array<MobileShaderToken>, base:String):String
	{
		var candidate = base;
		var suffix = 0;
		while (containsIdentifier(tokens, candidate))
		{
			suffix++;
			candidate = base + suffix;
		}
		return candidate;
	}

	private static function containsIdentifier(tokens:Array<MobileShaderToken>, name:String):Bool
	{
		for (token in tokens)
			if (token.kind == IDENTIFIER && token.text == name) return true;
		return false;
	}

	private static function containsTransformableIdentifier(tokens:Array<MobileShaderToken>, name:String):Bool
	{
		for (i in 0...tokens.length)
		{
			var token = tokens[i];
			if (!token.removed && token.kind == IDENTIFIER && token.text == name && canTransform(tokens, i)) return true;
		}
		return false;
	}

	private static function countGlobalFragmentOutputs(tokens:Array<MobileShaderToken>):Int
	{
		var count = 0;
		for (i in 0...tokens.length)
		{
			var token = tokens[i];
			if (!token.removed && !token.preprocessor && token.kind == IDENTIFIER && token.text == 'out'
				&& token.braceDepth == 0 && token.parenDepth == 0 && !isInterfaceBlockQualifier(tokens, i)
				&& parseSingleFragmentOutput(tokens, i) != null) count++;
		}
		return count;
	}

	private static function isInterfaceBlockQualifier(tokens:Array<MobileShaderToken>, qualifierIndex:Int):Bool
	{
		var next = nextSignificant(tokens, qualifierIndex);
		while (next >= 0 && (isPrecision(tokenValue(tokens[next])) || tokenValue(tokens[next]) == 'flat'
			|| tokenValue(tokens[next]) == 'smooth' || tokenValue(tokens[next]) == 'centroid'
			|| tokenValue(tokens[next]) == 'noperspective'))
			next = nextSignificant(tokens, next);
		if (next < 0) return false;
		if (tokenValue(tokens[next]) == '{') return true;
		var open = nextSignificant(tokens, next);
		return tokens[next].kind == IDENTIFIER && open >= 0 && tokenValue(tokens[open]) == '{';
	}

	private static function assignDepths(tokens:Array<MobileShaderToken>):Void
	{
		var brace = 0;
		var paren = 0;
		var bracket = 0;
		for (token in tokens)
		{
			token.braceDepth = brace;
			token.parenDepth = paren;
			token.bracketDepth = bracket;
			if (token.preprocessor || token.kind != SYMBOL) continue;
			switch (token.text)
			{
				case '{': brace++;
				case '}': if (brace > 0) brace--;
				case '(': paren++;
				case ')': if (paren > 0) paren--;
				case '[': bracket++;
				case ']': if (bracket > 0) bracket--;
			}
		}
	}

	private static function tokenize(source:String):Array<MobileShaderToken>
	{
		var result:Array<MobileShaderToken> = [];
		var index = 0;
		var line = 1;
		var lineStart = true;
		var inPreprocessor = false;

		while (index < source.length)
		{
			var start = index;
			var startLine = line;
			var code = StringTools.fastCodeAt(source, index);
			var kind = SYMBOL;

			if (code == 10)
			{
				var continued = false;
				if (inPreprocessor)
				{
					var previous = result.length - 1;
					while (previous >= 0 && result[previous].kind == WHITESPACE
						&& result[previous].line == startLine && result[previous].text.indexOf('\n') < 0) previous--;
					continued = previous >= 0 && result[previous].line == startLine && result[previous].text == '\\';
				}
				index++;
				result.push(makeToken('\n', WHITESPACE, startLine, inPreprocessor));
				line++;
				lineStart = !continued;
				inPreprocessor = continued;
				continue;
			}

			if (isHorizontalWhitespace(code))
			{
				kind = WHITESPACE;
				while (index < source.length && isHorizontalWhitespace(StringTools.fastCodeAt(source, index))) index++;
			}
			else if (code == 47 && index + 1 < source.length && StringTools.fastCodeAt(source, index + 1) == 47)
			{
				kind = COMMENT;
				index += 2;
				while (index < source.length && StringTools.fastCodeAt(source, index) != 10) index++;
			}
			else if (code == 47 && index + 1 < source.length && StringTools.fastCodeAt(source, index + 1) == 42)
			{
				kind = COMMENT;
				var commentHadNewline = false;
				index += 2;
				while (index < source.length)
				{
					if (StringTools.fastCodeAt(source, index) == 10)
					{
						line++;
						commentHadNewline = true;
					}
					if (StringTools.fastCodeAt(source, index) == 42 && index + 1 < source.length
						&& StringTools.fastCodeAt(source, index + 1) == 47)
					{
						index += 2;
						break;
					}
					index++;
				}
				if (commentHadNewline)
				{
					lineStart = true;
					inPreprocessor = false;
				}
			}
			else if (isIdentifierStart(code))
			{
				kind = IDENTIFIER;
				index++;
				while (index < source.length && isIdentifierPart(StringTools.fastCodeAt(source, index))) index++;
				lineStart = false;
			}
			else if (isDigit(code) || (code == 46 && index + 1 < source.length && isDigit(StringTools.fastCodeAt(source, index + 1))))
			{
				kind = NUMBER;
				index = scanNumber(source, index);
				lineStart = false;
			}
			else if (code == 34 || code == 39)
			{
				kind = STRING;
				var quote = code;
				index++;
				while (index < source.length)
				{
					var stringCode = StringTools.fastCodeAt(source, index++);
					if (stringCode == 92 && index < source.length) index++;
					else if (stringCode == quote) break;
					else if (stringCode == 10) line++;
				}
				lineStart = false;
			}
			else
			{
				index++;
				if (lineStart && code == 35) inPreprocessor = true;
				lineStart = false;
			}

			result.push(makeToken(source.substring(start, index), kind, startLine, inPreprocessor));
		}
		return result;
	}

	private static inline function makeToken(text:String, kind:Int, line:Int, preprocessor:Bool):MobileShaderToken
	{
		return {
			text: text,
			replacement: null,
			prefix: '',
			suffix: '',
			kind: kind,
			line: line,
			preprocessor: preprocessor,
			removed: false,
			braceDepth: 0,
			parenDepth: 0,
			bracketDepth: 0
		};
	}

	private static function render(tokens:Array<MobileShaderToken>):String
	{
		var output = new StringBuf();
		for (token in tokens)
		{
			if (token.removed)
			{
				for (i in 0...countNewlines(token.text)) output.add('\n');
				continue;
			}
			output.add(token.prefix);
			output.add(token.replacement != null ? token.replacement : token.text);
			output.add(token.suffix);
		}
		return output.toString();
	}

	private static function renderRange(tokens:Array<MobileShaderToken>, start:Int, end:Int):String
	{
		var output = new StringBuf();
		for (i in start...end)
			if (!tokens[i].removed)
			{
				output.add(tokens[i].prefix);
				output.add(tokenValue(tokens[i]));
				output.add(tokens[i].suffix);
			}
		return output.toString();
	}

	private static inline function tokenValue(token:MobileShaderToken):String
	{
		return token.replacement != null ? token.replacement : token.text;
	}

	private static function nextSignificant(tokens:Array<MobileShaderToken>, index:Int):Int
	{
		var i = index + 1;
		while (i < tokens.length)
		{
			if (!tokens[i].removed && tokens[i].kind != WHITESPACE && tokens[i].kind != COMMENT) return i;
			i++;
		}
		return -1;
	}

	private static function previousSignificant(tokens:Array<MobileShaderToken>, index:Int):Int
	{
		var i = index - 1;
		while (i >= 0)
		{
			if (!tokens[i].removed && tokens[i].kind != WHITESPACE && tokens[i].kind != COMMENT) return i;
			i--;
		}
		return -1;
	}

	private static function nextSignificantOnLine(tokens:Array<MobileShaderToken>, index:Int, line:Int):Int
	{
		var i = index + 1;
		while (i < tokens.length && tokens[i].line == line)
		{
			if (!tokens[i].removed && tokens[i].kind != WHITESPACE && tokens[i].kind != COMMENT) return i;
			i++;
		}
		return -1;
	}

	private static function nextSignificantInDirective(tokens:Array<MobileShaderToken>, index:Int):Int
	{
		var i = index + 1;
		while (i < tokens.length && tokens[i].preprocessor)
		{
			if (!tokens[i].removed && tokens[i].kind != WHITESPACE && tokens[i].kind != COMMENT) return i;
			i++;
		}
		return -1;
	}

	private static function findMatching(tokens:Array<MobileShaderToken>, openIndex:Int, open:String, close:String):Int
	{
		var depth = 0;
		for (i in openIndex...tokens.length)
		{
			if (tokens[i].removed || tokens[i].kind != SYMBOL) continue;
			var value = tokenValue(tokens[i]);
			if (value == open) depth++;
			else if (value == close && --depth == 0) return i;
		}
		return -1;
	}

	private static function parseLocationLayout(layout:String):Null<Int>
	{
		var regex = ~/^\s*location\s*=\s*([0-9]+)\s*$/;
		return regex.match(layout) ? Std.parseInt(regex.matched(1)) : null;
	}

	private static function parseExtensionName(line:String):Null<String>
	{
		var regex = ~/#\s*extension\s+([A-Za-z0-9_]+)/;
		return regex.match(line) ? regex.matched(1) : null;
	}

	private static function hasExtension(name:String):Bool
	{
		return extensions.exists(normalizeExtensionName(name));
	}

	private static function normalizeExtensionName(name:String):String
	{
		if (name == null) return '';
		name = StringTools.trim(name);
		return StringTools.startsWith(name, 'GL_') ? name.substr(3) : name;
	}

	private static function addExtension(output:Array<String>, line:String):Void
	{
		for (existing in output)
			if (StringTools.trim(existing) == StringTools.trim(line)) return;
		output.push(line);
	}

	private static function addDiagnostic(output:Array<MobileShaderDiagnostic>, stage:String, line:Int, message:String):Void
	{
		for (diagnostic in output)
			if (diagnostic.stage == stage && diagnostic.line == line && diagnostic.message == message) return;
		output.push({stage: stage, line: line, message: message});
	}

	private static function sanitizeComment(value:String):String
	{
		return StringTools.replace(StringTools.replace(value, '\r', ' '), '\n', ' ');
	}

	private static function countNewlines(value:String):Int
	{
		var result = 0;
		for (i in 0...value.length)
			if (StringTools.fastCodeAt(value, i) == 10) result++;
		return result;
	}

	private static inline function isPrecision(value:String):Bool
	{
		return value == 'lowp' || value == 'mediump' || value == 'highp';
	}

	private static inline function isHorizontalWhitespace(code:Int):Bool
	{
		return code == 9 || code == 11 || code == 12 || code == 32;
	}

	private static inline function isIdentifierStart(code:Int):Bool
	{
		return (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || code == 95;
	}

	private static inline function isIdentifierPart(code:Int):Bool
	{
		return isIdentifierStart(code) || isDigit(code);
	}

	private static inline function isDigit(code:Int):Bool
	{
		return code >= 48 && code <= 57;
	}

	private static inline function isHexDigit(code:Int):Bool
	{
		return isDigit(code) || (code >= 65 && code <= 70) || (code >= 97 && code <= 102);
	}

	private static function scanNumber(source:String, start:Int):Int
	{
		var index = start;
		var length = source.length;
		var hexadecimal = index + 1 < length && StringTools.fastCodeAt(source, index) == 48
			&& (StringTools.fastCodeAt(source, index + 1) == 88 || StringTools.fastCodeAt(source, index + 1) == 120);

		if (hexadecimal)
		{
			index += 2;
			while (index < length && isHexDigit(StringTools.fastCodeAt(source, index))) index++;
			if (index < length && StringTools.fastCodeAt(source, index) == 46)
			{
				index++;
				while (index < length && isHexDigit(StringTools.fastCodeAt(source, index))) index++;
			}
			if (index < length && (StringTools.fastCodeAt(source, index) == 80 || StringTools.fastCodeAt(source, index) == 112))
			{
				index++;
				if (index < length && (StringTools.fastCodeAt(source, index) == 43 || StringTools.fastCodeAt(source, index) == 45)) index++;
				while (index < length && isDigit(StringTools.fastCodeAt(source, index))) index++;
			}
		}
		else
		{
			if (StringTools.fastCodeAt(source, index) == 46) index++;
			while (index < length && isDigit(StringTools.fastCodeAt(source, index))) index++;
			if (index < length && StringTools.fastCodeAt(source, index) == 46)
			{
				index++;
				while (index < length && isDigit(StringTools.fastCodeAt(source, index))) index++;
			}
			if (index < length && (StringTools.fastCodeAt(source, index) == 69 || StringTools.fastCodeAt(source, index) == 101))
			{
				index++;
				if (index < length && (StringTools.fastCodeAt(source, index) == 43 || StringTools.fastCodeAt(source, index) == 45)) index++;
				while (index < length && isDigit(StringTools.fastCodeAt(source, index))) index++;
			}
		}

		// Preserve standard scalar suffixes without ever consuming an arbitrary
		// identifier or the following operator/function name.
		if (index < length)
		{
			var suffix = StringTools.fastCodeAt(source, index);
			if (suffix == 70 || suffix == 102 || suffix == 85 || suffix == 117) index++;
			else if ((suffix == 76 || suffix == 108) && index + 1 < length)
			{
				var next = StringTools.fastCodeAt(source, index + 1);
				if (next == 70 || next == 102) index += 2;
			}
		}
		return index;
	}
}
