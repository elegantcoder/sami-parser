cssParse = require 'css-parse'
langCodes = require './lang_codes.js'

# from http://phpjs.org/functions/strip_tags/
`function strip_tags(input, allowed) {
  // http://kevin.vanzonneveld.net
  // +   original by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
  // +   improved by: Luke Godfrey
  // +      input by: Pul
  // +   bugfixed by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
  // +   bugfixed by: Onno Marsman
  // +      input by: Alex
  // +   bugfixed by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
  // +      input by: Marc Palau
  // +   improved by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
  // +      input by: Brett Zamir (http://brett-zamir.me)
  // +   bugfixed by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
  // +   bugfixed by: Eric Nagel
  // +      input by: Bobby Drake
  // +   bugfixed by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
  // +   bugfixed by: Tomasz Wesolowski
  // +      input by: Evertjan Garretsen
  // +    revised by: Rafał Kukawski (http://blog.kukawski.pl/)
  // *     example 1: strip_tags('<p>Kevin</p> <br /><b>van</b> <i>Zonneveld</i>', '<i><b>');
  // *     returns 1: 'Kevin <b>van</b> <i>Zonneveld</i>'
  // *     example 2: strip_tags('<p>Kevin <img src="someimage.png" onmouseover="someFunction()">van <i>Zonneveld</i></p>', '<p>');
  // *     returns 2: '<p>Kevin van Zonneveld</p>'
  // *     example 3: strip_tags("<a href='http://kevin.vanzonneveld.net'>Kevin van Zonneveld</a>", "<a>");
  // *     returns 3: '<a href='http://kevin.vanzonneveld.net'>Kevin van Zonneveld</a>'
  // *     example 4: strip_tags('1 < 5 5 > 1');
  // *     returns 4: '1 < 5 5 > 1'
  // *     example 5: strip_tags('1 <br/> 1');
  // *     returns 5: '1  1'
  // *     example 6: strip_tags('1 <br/> 1', '<br>');
  // *     returns 6: '1  1'
  // *     example 7: strip_tags('1 <br/> 1', '<br><br/>');
  // *     returns 7: '1 <br/> 1'
  allowed = (((allowed || "") + "").toLowerCase().match(/<[a-z][a-z0-9]*>/g) || []).join(''); // making sure the allowed arg is a string containing only tags in lowercase (<a><b><c>)
  var tags = /<\/?([a-z][a-z0-9]*)\b[^>]*>/gi,
    commentsAndPhpTags = /<!--[\s\S]*?-->|<\?(?:php)?[\s\S]*?\?>/gi;
  return input.replace(commentsAndPhpTags, '').replace(tags, function($0, $1) {
    return allowed.indexOf('<' + $1.toLowerCase() + '>') > -1 ? $0 : '';
  });
}`

reOpenSync = /<sync/i
reLineEnding = /\r\n?|\n/g
reBrokenTag = /<[a-z]*[^>]*<[a-z]*/g
reStartTime = /<sync[^>]+?start[^=]*=[^0-9]*([0-9]*)["^0-9"]*/i
reBr = /<br[^>]*>/ig
reStyle = /<style[^>]*>([\s\S]*?)<\/style[^>]*>/i
reComment = /(<!--|-->)/g

class Parser
  @defaultLanguage: {className: 'KRCC', lang: 'ko', reClassName: /class[^=]*?=["']?(KRCC)["']?/i}
  @defaultLanguageCode: 'ko' 
  availableLanguages: null
  errors: null

  constructor: () ->
    @errors = []
    @availableLanguages = []

  _parse: (str) ->
    lineNum = 1
    ret = []

    while true
      startTagIdx = str.search(reOpenSync)
      break if nextStartTagIdx <= 0 || startTagIdx < 0
      nextStartTagIdx = str.slice(startTagIdx+1).search(reOpenSync)+1
      if nextStartTagIdx > 0
        element = str.slice(startTagIdx, startTagIdx+nextStartTagIdx)
      else
        element = str.slice(startTagIdx)

      lineNum += str.slice(0, startTagIdx).match(reLineEnding)?.length or 0 
      if isBroken = reBrokenTag.test(element)
        e = new Error('ERROR_BROKEN_TAGS')
        e.line = lineNum
        e.context = element
        @errors.push(e)

      str = str.slice(startTagIdx+nextStartTagIdx)

      startTime = +element.match(reStartTime)?[1] or -1

      if startTime < 0
        e = new Error('ERROR_INVALID_TIME')
        e.line = lineNum
        e.context = element
        @errors.push(e)

      lineNum += element.match(reLineEnding)?.length or 0

      for lang in @availableLanguages when lang.reClassName.test element
        lang = lang.lang
        break;

      lang or= @defaultLanguageCode
      element = element.replace(reLineEnding, '')
      element = element.replace(reBr, "\n")
      innerText = strip_tags(element).trim()
      lang = @getLanguage(element)
      item = {startTime, languages: {}, contents: innerText}
      item.languages[lang] = innerText
      ret.push(item)

    ret.sort((a, b) ->
      a.startTime - b.startTime
    )

    i = ret.length
    while i--
      item = ret[i]
      ret[i-1]?.endTime = item.startTime
      if !item.contents or item.contents is '&nbsp;'
        ret.splice i, 1
      else
        delete ret[i].contents

    return ret

  getLanguage: (element) ->
    for lang in @availableLanguages when lang.reClassName.test element
      return lang.lang
    return Parser.defaultLanguage.lang

  getAvailableLanguages: (str) ->
    try
      matched = str.match(reStyle)?[1] or ''
      matched = matched.replace(reComment, '')
      parsed = cssParse matched

      for rule in parsed.stylesheet.rules
        # currently support single language, class selectors only
        selector = rule.selectors[0]
        if selector?[0] is '.'
          for declaration in rule.declarations
            if declaration.property.toLowerCase() is 'lang'
              className = selector.slice(1) # pass dot (.ENCC -> ENCC)
              lang = declaration.value.slice(0,2)
              if ~langCodes.indexOf lang
                language = {
                  className: className
                  lang: lang
                  reClassName: new RegExp("class[^=]*?=[\"']?(#{className})['\"]?", 'i')
                }
                @availableLanguages.push language
              else
                throw Error()
    catch e
      @errors.push error = new Error('ERROR_INVALID_LANGUAGE')
      @availableLanguages.push Parser.defaultLanguage # parse failed
      return

  parse: (str) ->
    @getAvailableLanguages(str)
    result = @_parse(str)
    return {result, errors: @errors}

module.exports = Parser