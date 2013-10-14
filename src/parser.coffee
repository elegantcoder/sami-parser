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
reCloseSync = /<sync|<\/body|<\/sami/i
reLineEnding = /\r\n?|\n/g
reBrokenTag = /<[a-z]*[^>]*<[a-z]*/g
reStartTime = /<sync[^>]+?start[^=]*=[^0-9]*([0-9]*)["^0-9"]*/i
reBr = /<br[^>]*>/ig
reStyle = /<style[^>]*>([\s\S]*?)<\/style[^>]*>/i
reComment = /(<!--|-->)/g

_sort = (langItem) ->
  langItem.sort((a, b) ->
    if (res = a.startTime - b.startTime) is 0
      return a.endTime - b.endTime
    else
      return res
  )

_makeEndTime = (langItem) ->
  i = langItem.length
  while i--
    item = langItem[i]
    langItem[i-1]?.endTime = item.startTime
    if !item.contents or item.contents is '&nbsp;'
      langItem.splice i, 1
    else
      delete langItem[i].contents
  langItem

_mergeMultiLanguages = (arr) ->
  dict = {}
  i = arr.length 
  ret = []

  for val, i in arr
    key = val.startTime+','+val.endTime
    if (idx = dict[key]) isnt undefined
      for lang, content of val.languages
        ret[idx].languages[lang] = content
    else
      ret.push val
      dict[key] = ret.length-1

  return ret

class Parser
  definedLangs: null
  errors: null

  constructor: () ->
    @errors = []
    @definedLangs = {
      KRCC: {
        lang: 'ko'
        reClassName: new RegExp("class[^=]*?=[\"'\S]*(KRCC)['\"\S]?", 'i')
      },
      ENCC: {
        lang: 'en'
        reClassName: new RegExp("class[^=]*?=[\"'\S]*(ENCC)['\"\S]?", 'i')
      },
      JPCC: {
        lang: 'ja'
        reClassName: new RegExp("class[^=]*?=[\"'\S]*(JPCC)['\"\S]?", 'i')
      }
    }

  _parse: (str) ->
    lineNum = 1
    ret = []
    tempRet = {}

    while true
      startTagIdx = str.search(reOpenSync)
      break if nextStartTagIdx <= 0 || startTagIdx < 0
      nextStartTagIdx = str.slice(startTagIdx+1).search(reCloseSync)+1
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
      
      lang = @getLanguage(element)
      if !lang
        e = new Error('ERROR_INVALID_LANGUAGE')
        e.line = lineNum
        e.context = element
        @errors.push(e)

      lineNum += element.match(reLineEnding)?.length or 0
      element = element.replace(reLineEnding, '')
      element = element.replace(reBr, "\n")
      innerText = strip_tags(element).trim()
      item = {startTime, languages: {}, contents: innerText}
      if lang
        item.languages[lang] = innerText

      tempRet[lang] or= []
      tempRet[lang].push(item)

    for lang, langItem of tempRet
      langItem = _sort(langItem)
      langItem = _makeEndTime(langItem)

      ret = ret.concat(langItem)

    ret = _mergeMultiLanguages(ret)
    ret = _sort(ret)
    return ret

  # returns one of the defined languages or the element's first className.
  getLanguage: (element) ->
    for className, lang of @definedLangs when lang.reClassName.test element
      return lang.lang

  getDefinedLangs: (str) ->
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
                @definedLangs[className] = {
                  lang: lang
                  reClassName: new RegExp("class[^=]*?=[\"'\S]*(#{className})['\"\S]?", 'i')
                }
              else
                throw Error()
    catch e
      @errors.push error = new Error('ERROR_INVALID_LANGUAGE_DEFINITION')
      return

  parse: (str) ->
    @getDefinedLangs(str)
    result = @_parse(str)
    return {result, errors: @errors}

module.exports = Parser