const nlp = require('compromise/two')

const tagPriority = [
  'Verb',
  'Noun',
  'Adjective',
  'Adverb',
  'Preposition',
  'Conjunction',
  'Determiner',
  'Pronoun',
  'Value',
  'QuestionWord',
  'Expression',
  'Url',
  'HashTag',
  'AtMention',
]

const aliases = {
  Person: 'Noun',
  Place: 'Noun',
  Organization: 'Noun',
  ProperNoun: 'Noun',
  Date: 'Value',
  NumericValue: 'Value',
  Money: 'Value',
  Percent: 'Value',
}

function readStdin() {
  return new Promise((resolve, reject) => {
    let input = ''

    process.stdin.setEncoding('utf8')
    process.stdin.on('data', chunk => {
      input += chunk
    })
    process.stdin.on('end', () => resolve(input))
    process.stdin.on('error', reject)
  })
}

function pickTag(tags) {
  for (const tag of tagPriority) {
    if (tags.includes(tag)) {
      return tag
    }
  }

  for (const tag of tags) {
    if (aliases[tag]) {
      return aliases[tag]
    }
  }

  return null
}

function lineStarts(text) {
  const starts = [0]

  for (let index = 0; index < text.length; index += 1) {
    if (text[index] === '\n') {
      starts.push(index + 1)
    }
  }

  return starts
}

function positionAt(text, starts, offset) {
  let low = 0
  let high = starts.length - 1

  while (low <= high) {
    const middle = Math.floor((low + high) / 2)

    if (starts[middle] <= offset) {
      low = middle + 1
    } else {
      high = middle - 1
    }
  }

  const row = Math.max(0, high)

  return {
    row,
    col: Buffer.byteLength(text.slice(starts[row], offset), 'utf8'),
  }
}

function rangesFor(text) {
  const starts = lineStarts(text)
  const data = nlp(text).json({ offset: true })
  const ranges = []

  for (const sentence of data) {
    for (const term of sentence.terms || []) {
      const tag = pickTag(term.tags || [])

      if (!tag || !term.offset || term.offset.start == null || term.offset.length == null) {
        continue
      }

      const start = positionAt(text, starts, term.offset.start)
      const end = positionAt(text, starts, term.offset.start + term.offset.length)

      ranges.push({
        tag,
        start_row: start.row,
        start_col: start.col,
        end_row: end.row,
        end_col: end.col,
        text: term.text,
      })
    }
  }

  return ranges
}

readStdin()
  .then(text => {
    process.stdout.write(JSON.stringify(rangesFor(text)))
  })
  .catch(error => {
    process.stderr.write(`${error.stack || error.message}\n`)
    process.exit(1)
  })
