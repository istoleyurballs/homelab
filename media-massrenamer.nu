def "main mass" [...files: string] {
  # let out = $files
  #   | wrap filename
  #   | insert media_name {$in.filename | parse-medianame}
  #   | insert resolution {$in.filename | parse-resolution}
  #   | insert rip {$in.filename | parse-rip}
  #   | insert hdr {$in.filename | parse-hdr}
  #   | insert codec {$in.filename | parse-codec}
  #   | insert ext {$in.filename | parse-ext}
  #   | insert newName {$in.media_name}

  let out = $files | each {parse-all $in}

  print ($out | update filename {path basename})
}

def "main single" [
  file: string, # Target file to rename.
  --target-base-dir (-t): string, # Directory to put the renamed file in.
  --mv, # Enable to use `mv` instead of `ln`.
] {
  if not ($file | path exists) {
    print "This file doesn't exists"
    exit 1
  }
  if ($file | path type) != 'file' {
    print "Not a file"
    exit 1
  }

  let file = $file | path expand --strict --no-symlink

  let data = parse-all $file --interactive
  print $data

  let continue = ['Yes', 'No'] | input list 'Looks good ?'
  if $continue != 'Yes' {
    exit 1
  }

  let target_base_dir = $target_base_dir | default ($file | path dirname)

  let target_dir = $"($target_base_dir)/($data.target_dir_name)"

  print $"mkdir -p '($target_dir)'"
  print $"(if $mv { 'mv' } else { 'ln' }) '($file)' '($target_dir)/($data.target_file_name)'"
}

def "main season" [
  source_dir: string, # Directory to get the episodes from.
  --target-dir: string, # Alternative directory to put the episodes in, defaults to `source_dir`.
  --keep-filter (-f): string = '.*', # Regex that needs to match for the episode to be considered.
  --offset-ep: int = 0, # Will add this offset to the episode number.
  --mv, # Enable to use `mv` instead of `ln`.
] {
  if not ($source_dir | path exists) {
    print "This source doesn't exist"
    exit 1
  }
  if ($source_dir | path type) != 'dir' {
    print "Source isn't a directory"
    exit 1
  }

  let target_dir = $target_dir | default $source_dir

  if not ($target_dir | path exists) {
    print "This target doesn't exist"
    exit 1
  }
  if ($target_dir | path type) != 'dir' {
    print "Target isn't a directory"
    exit 1
  }

  let source_dir = $source_dir | path expand
  let target_dir = $target_dir | path expand

  let media = $target_dir | path dirname | parse-medianame
  let media = (input --default $media "Media: ")
  let year = $target_dir | path dirname | parse-year
  let year = (input --default $year "Year: ")
  let season = $target_dir | path basename | parse 'Season.{s}' | get -o 0.s | default '1' | into int | into string
  let season = (input --default=$season "Season: ") | into int

  let items = ls $source_dir
    | where type == file
    | where name =~ $keep_filter
    | get name
    | each {parse-season-item $in --season=$season --prefix=$media --offset-ep=$offset_ep}
    | sort-by --natural ep

  let data = {
    media: $media
    year: $year
    items: $items
    target_dir: $target_dir
  }

  print ($data | update items {update filename {path basename}} | table --expand)

  let items = $items | update target_file_name {$"($target_dir)/($in)"}

  if ($items | group-by target_file_name | values | each {length} | any {$in > 1}) {
    print "ERROR: There are duplicated target filenames"
    exit 1
  }

  print ($items
    | where {$in.filename != $in.target_file_name}
    | each {$"(if $mv { 'mv' } else { 'ln' }) '($in.filename | str replace "\'" "\\'")' '($in.target_file_name)'"} | str join "\n"
  )
}

def main [] {
  print "See --help"
  exit 1
}

def parse-all [file: string, --interactive] {
  let data = {
    filename: $file
    media_name: ($file | parse-medianame)
    year: ($file | parse-year)
    extra: ''
    resolution: ($file | parse-resolution)
    rip: ($file | parse-rip)
    hdr: ($file | parse-hdr)
    codec: ($file | parse-codec)
    ext: ($file | parse-ext)
  }

  let data = if $interactive {
    {
      filename: $data.filename
      media_name: (input --default $data.media_name "Media name: ")
      year: (input --default $data.year "Year: ")
      extra: (input "Extra: ")
      resolution: (input --default $data.resolution "Resolution: ")
      rip: (input --default $data.rip "Rip: ")
      hdr: (input --default $data.hdr "HDR: ")
      codec: (input --default $data.codec "Codec: ")
      ext: (input --default $data.ext "Ext: ")
    }
  } else {
    $data
  }

  mut target_base = $data.media_name
  if ($data.year | is-not-empty) {
    $target_base += '.' + $data.year
  }

  mut target_dir_name = $target_base
  mut target_file_name = $target_base + '-'

  if ($data.extra | is-not-empty) {
    $target_file_name += $data.extra + '.'
  }
  if ($data.resolution | is-not-empty) {
    $target_file_name += $data.resolution + '.'
  }
  if ($data.rip | is-not-empty) {
    $target_file_name += $data.rip + '.'
  }
  if ($data.hdr | is-not-empty) {
    $target_file_name += $data.hdr + '.'
  }
  $target_file_name += $data.codec + '.'
  $target_file_name += $data.ext

  { ...$data, target_dir_name: $target_dir_name, target_file_name: $target_file_name  }
}

def parse-season-item [file: string, --season: int, --prefix: string, --offset-ep: int] {
  print $"INFO: Parsing ($file | path basename)"

  mut data = {
    filename: $file,
    ep: ($file | parse-ep $season),
    resolution: ($file | parse-resolution),
    rip: ($file | parse-rip),
    hdr: ($file | parse-hdr),
    codec: ($file | parse-codec),
    ext: ($file | parse-ext)
  }

  if $offset_ep != 0 {
    $data.ep_corrected = ($file | parse-ep $season --offset-ep=$offset_ep)
  }

  if $data.ext == 'srt' {
    # Try find lang
    $data.srt_lang = ($file | parse-srt-lang)

    # Find corresponding season item file
    let candidates = ls ($file | path dirname)
      | select name
      | insert ep {$in.name | parse-ep $season}
      | insert ext {$in.name | parse-ext}
      | where ep == $data.ep
      | where ext in [mkv, mp4]

    if ($candidates | length) == 1 {
      # Found, use the data from the video item so its renamed correctly
      let data_ref = parse-season-item $candidates.0.name --prefix=$prefix --offset-ep=$offset_ep
      $data = $data | merge ($data_ref | select ep resolution rip hdr codec) | insert piggyback true
    }
  }

  mut target_file_name = $prefix + '.' + ($data | get -o ep_corrected | default $data.ep) + '-'

  $target_file_name += $data.resolution + '.'
  if ($data.rip | is-not-empty) {
    $target_file_name += $data.rip + '.'
  }
  if ($data.hdr | is-not-empty) {
    $target_file_name += $data.hdr + '.'
  }
  $target_file_name += $data.codec + '.'
  if ($data | get -o srt_lang | is-not-empty) {
    $target_file_name += $data.srt_lang + '.'
  }
  $target_file_name += $data.ext

  { ...$data, target_file_name: $target_file_name }
}

def parse-medianame []: string -> string {
  path basename
    | parse --regex '^(?<name>.+)[^a-zA-Z0-9](?<year>[12]\d{3}\)?)(?:[^a-zA-Z0-9]|$)'
    | get -o 0.name
    | default ''
}

# Actually the exact same regex as the name
def parse-year []: string -> string {
  path basename
    | parse --regex '^(?<name>.+)[^a-zA-Z0-9](?<year>[12]\d{3}\)?)(?:[^a-zA-Z0-9]|$)'
    | get -o 0.year
    | default ''
}

def parse-resolution []: string -> string {
  let file = $in
  $file
    | path basename
    | parse --regex '[^a-zA-Z0-9](?<resolution>(?:720|1080|2160)p|UHD)[^a-zA-Z0-9]'
    | get -o 0.resolution
    | default {
      print "WARN: Could not find resolution in name, using ffprobe"
      ^ffprobe -v quiet -output_format json -show_streams -i $file
        | from json
        | get streams
        | where codec_type == video
        | get -o 0.height
        | $"($in)"
    }
    | str replace --regex '^(\d+)$' '${1}p'
    | str replace 'UHD' '2160p'
    | str replace '544p' '720p'
    | str replace '814p' '1080p'
    | str replace '816p' '1080p'
}

def parse-rip []: string -> string {
  path basename
    | parse --regex '(?i)[^a-zA-Z0-9](?<rip>blu-?ray|[a-z]+rip|web[a-z-]*|h?dts|hdtv)[^a-zA-Z0-9]'
    | get -o 0.rip
    | default ''
    | str replace --regex '(?i)blu-?ray' 'BluRay'
    | str replace --regex '(?i)web-?dl' 'WEBDL'
    | str replace --regex '(?i)web' 'WEB'
}

def parse-hdr []: string -> string {
  path basename
    | parse --regex '(?i)[^a-zA-Z0-9](?<hdr>[a-z0-9]*hdr[a-z0-9]*)[^a-zA-Z0-9]'
    | get -o 0.hdr
    | default ''
    | str replace --regex '.+' 'HDR'
}

def parse-codec []: string -> string {
  let file = $in
  $file
    | path basename
    | parse --regex '(?i)[^a-zA-Z0-9](?<codec>[hx]\.?26[456]|av1|avc|hevc)[^a-zA-Z0-9]'
    | get -o 0.codec
    | default {
      print "WARN: Could not find codec in name, using ffprobe"
      ^ffprobe -v quiet -output_format json -show_streams -i $file
        | from json
        | get streams
        | where codec_type == video
        | get -o 0.codec_name
    }
    | default ''
    | str upcase
    | str replace --regex '[HX]\.?264' 'AVC'
    | str replace --regex '[HX]\.?265' 'HEVC'
}

def parse-ext []: string -> string {
  parse --regex '(?i)\.(?<ext>[a-zA-Z0-9]+)$'
    | get 0.ext
    | str downcase
}

def parse-ep [season: int, --offset-ep: int = 0]: string -> string {
  let file = $in
  $file
    | path basename
    | parse --regex '(?:[^a-zA-Z0-9][sS]|[^0-9])(?<s>\d{1,2})[^0-9]?[eEx](?<e>\d{1,3})[^a-zA-Z0-9]'
    | get -o 0
    | default {
      print "WARN: Using degraded ep parser"

      let fallback_e = $file
        | path basename
        | parse --regex '[^a-zA-Z][eE](?<e>\d{1,3})[^0-9]'
        | get -o 0.e
        | default {$file | path basename | parse --regex '(?:[^0-9](?<e>\d{2,3})[^0-9])' | get -o 0.e}
        | default {$file | path basename | parse --regex '(?<e>[0-9]{2,3})[^0-9]' | get 0.e}

      { s: $season, e: $fallback_e }
    }
    | update e {($in | into int) + $offset_ep}
    | $"S($in.s | fill -a r -w 2 -c 0)E($in.e | fill -a r -w 2 -c 0)"
}

def parse-srt-lang []: string -> string {
  path basename
    | parse --regex '\.(?<lang>[a-z]{2,3})\.srt$'
    | get -o 0.lang
    | default ''
}

# vim: set tabstop=2 shiftwidth=2 expandtab :
