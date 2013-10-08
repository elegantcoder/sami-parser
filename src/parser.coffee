_ = require 'lodash'
cssParse = require 'css-parse'

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

class Parser
  @defaultLanguage: {className: 'KRCC', lang: 'ko', reClassName: /class[^=]*?=["']?(KRCC)["']?/i}
  @defaultLanguageCode: 'ko' 
  availableLanguages: null
  errors: null

  constructor: () ->
    @errors = []
    @availableLanguages = []

  getSyncElements: (str) ->
    lineNum = 1
    ret = []

    while true
      startTagIdx = str.search(/<sync/i)
      break if nextStartTagIdx <= 0 || startTagIdx < 0
      nextStartTagIdx = str.slice(startTagIdx+1).search(/<sync/i)+1
      if nextStartTagIdx > 0
        sliced = str.slice(startTagIdx, startTagIdx+nextStartTagIdx)
      else
        sliced = str.slice(startTagIdx)

      lineNum += str.slice(0, startTagIdx).match(/\r\n?|\n/g)?.length or 0 
      if isBroken = /<[a-z]*[^>]*<[a-z]*/g.test(sliced)
        e = new Error('ERROR_BROKEN_TAGS')
        e.line = lineNum
        e.context = sliced
        @errors.push(e)

      ret.push(sliced)
      str = str.slice(startTagIdx+nextStartTagIdx)
      lineNum += sliced.match(/\r\n?|\n/g)?.length or 0

    return ret

  _parse: (elements) ->
    ret = []
    prev = null

    # sort by start time
    elements = _.sortBy(elements, (syncElement) ->
      +syncElement.match(/<sync[^>]+?start[^=]*=[^0-9]*([0-9]*)[^0-9]*/i)?[1] or -1
    )

    elements.forEach((element) =>
      startTime = +element.match(/<sync[^>]+?start[^=]*=[^0-9]*([0-9]*)[^0-9]*/i)?[1] or 0
      for lang in @availableLanguages when lang.reClassName.test element
        lang = lang.lang
        break;

      lang or= @defaultLanguageCode # language 가 없으면 default

      if prev
        prev.endTime = startTime
        ret.push prev
        prev = null

      element = element.replace(/[\r\n]/g, '')
      element = element.replace(/<br[^>]*>/ig, "\n")
      innerText = strip_tags(element).trim()
      unless innerText is '&nbsp;'
        prev = {startTime, languages: {}}
        prev.languages[lang] = innerText
    )

    # for the last element that is not pushed
    if prev
      prev.endTime = prev.startTime + 10000 #arbitrarily, 10 seconds 
      ret.push prev
    return ret

  getAvailableLanguages: (str) ->
    try
      matched = str.match(/<style[^>]*>([\s\S]*?)<\/style[^>]*>/i)?[1] or ''
      matched = matched.replace(/(<!--|-->)/g, '')
      parsed = cssParse matched

      for rule in parsed.stylesheet.rules
        # currently support single language, class selectors only
        selector = rule.selectors[0]
        if selector?[0] is '.'
          for declaration in rule.declarations
            if declaration.property.toLowerCase() is 'lang'
              className = selector.slice(1) # pass dot (.ENCC -> ENCC)
              language = {
                className: className
                lang: declaration.value.slice(0,2)
                reClassName: new RegExp("class[^=]*?=[\"']?(#{className})['\"]?", 'i')
              }
              @availableLanguages.push language
    catch e
      @errors.push error = new Error('ERROR_UNAVAILABLE_LANGUAGE')
      @availableLanguages.push Parser.defaultLanguage # parse failed
      return

  parse: (str) ->
    @getAvailableLanguages(str)
    syncElements = @getSyncElements(str)
    result = @_parse(syncElements)
    return {result, errors: @errors}

module.exports = Parser