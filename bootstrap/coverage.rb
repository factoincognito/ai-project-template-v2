# coverage.rb: the Ruby part of bootstrap/coverage.sh (PBI-1.41 c2), which
# starts it; the JSON of bashcov's result sets is read here. Ruby 2.6 or
# later, no gems. Not a .sh, so outside the scripts' lint, format and
# coverage gates.
#
#   ruby coverage.rb map <root> <resultset> <out> <name> <counted>...
#       maps one suite's result set onto the counted scripts (see
#       coverage.sh run) and writes <out>.
#   ruby coverage.rb gate <minimum> <results> <root> <n> <name>... <counted>...
#       merges the n named results and gates them (see coverage.sh gate).
require "json"

def lines_of(c)
  c.is_a?(Hash) ? c["lines"] : c
end

def add(a, b)
  (0...[a.size, b.size].max).map do |i|
    x = a[i]
    y = b[i]
    x.nil? && y.nil? ? nil : x.to_i + y.to_i
  end
end

STAMPS = { "{{TEMPLATE_VERSION}}" => "v[0-9]+\\.[0-9]+\\.[0-9]+", "{{TEMPLATE_COMMIT}}" => "[0-9a-f]{40}" }.freeze

def copy_of?(copy, script)
  c = begin
    File.readlines(copy)
  rescue StandardError
    nil
  end
  s = File.readlines(script)
  return false unless c && c.size == s.size
  c.each_with_index.all? do |line, i|
    next true if line == s[i]
    next false unless STAMPS.keys.any? { |k| s[i].include?(k) }
    re = Regexp.escape(s[i])
    STAMPS.each { |k, v| re = re.gsub(Regexp.escape(k), v) }
    line.match?(/\A#{re}\z/)
  end
end

def counted_lines(lines)
  lines.is_a?(Array) && lines.all? { |x| x.nil? || x.is_a?(Integer) }
end

mode = ARGV.shift
case mode
when "map"
  root, resultset, out, name = ARGV.shift(4)
  counted = ARGV
  root = File.realpath(root)
  by_name = counted.group_by { |p| File.basename(p) }
  twice = by_name.select { |_, v| v.size > 1 }.keys
  abort "coverage.sh: two counted scripts share a name, so a copy cannot be mapped: #{twice.join(", ")}" unless twice.empty?
  files = {}
  size = {}
  mapped = 0
  dropped = 0
  JSON.parse(File.read(resultset)).each_value do |run|
    run.fetch("coverage").each do |path, c|
      lines = lines_of(c)
      next unless counted_lines(lines)
      if path.start_with?(root + "/")
        rel = path[(root.size + 1)..-1]
        next unless counted.include?(rel)
      else
        script = (by_name[File.basename(path)] || []).first
        next unless script
        unless copy_of?(path, File.join(root, script))
          dropped += 1
          next
        end
        rel = script
        mapped += 1
      end
      # bashcov can report lines past a script's end (bootstrap/build.sh, 296
      # lines, gets results of 299); they are no lines of it.
      lines = lines.first(size[rel] ||= File.readlines(File.join(root, rel)).size)
      files[rel] = files[rel] ? add(files[rel], lines) : lines
    end
  end
  File.write(out, JSON.generate("name" => name, "files" => files) + "\n")
  puts "coverage.sh: #{name}: #{mapped} copies mapped onto their scripts, #{dropped} files named like a counted script left out (not copies)"
when "gate"
  min, dir, root, n = ARGV.shift(4)
  min = min.to_i
  names = ARGV.shift(n.to_i)
  counted = ARGV
  problems = []
  files = {}
  names.each do |nm|
    f = File.join(dir, nm + ".json")
    unless File.file?(f)
      problems << "no result #{nm}: there is no #{nm}.json in #{dir}"
      next
    end
    data = begin
      JSON.parse(File.read(f))
    rescue StandardError
      nil
    end
    unless data.is_a?(Hash) && data["name"] == nm && data["files"].is_a?(Hash) && data["files"].values.all? { |l| counted_lines(l) }
      problems << "#{f} is not a result of coverage.sh run"
      next
    end
    data["files"].each { |p, l| files[p] = files[p] ? add(files[p], l) : l }
  end
  if File.directory?(dir)
    (Dir.children(dir).sort - names.map { |nm| nm + ".json" }).each { |x| problems << "a result that was not expected: #{x}" }
  end
  counted.each do |p|
    if !files.key?(p)
      problems << "no result for #{p}, a counted script"
    elsif files[p].size > (len = File.readlines(File.join(root, p)).size)
      problems << "the result for #{p} has #{files[p].size} lines, more than the script's #{len}"
    end
  end
  unless problems.empty?
    problems.each { |x| warn "coverage.sh: #{x}" }
    exit 1
  end
  hit = 0
  total = 0
  counted.each do |p|
    l = files[p].compact
    h = l.count(&:positive?)
    hit += h
    total += l.size
    printf("%5.1f%% %5d/%5d %s\n", l.empty? ? 0 : 100.0 * h / l.size, h, l.size, p)
  end
  abort "coverage.sh: the counted scripts have no line that counts" if total.zero?
  pct = format("%.1f", 100.0 * hit / total)
  puts "Total: #{pct}% (#{hit} of #{total} lines) of #{counted.size} scripts; the minimum is #{min}%."
  if hit * 100 < min * total
    warn "coverage.sh: Line coverage is #{pct}%, below the minimum of #{min}%: add tests for the lines no test runs."
    exit 1
  end
else
  abort "coverage.sh: unknown mode #{mode}"
end
