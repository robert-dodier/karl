#!/usr/bin/ruby

# For documentation, see the README.md file in the same subdirectory as this script.

require 'digest'
require 'fileutils'

def main()
  t = gets(nil)
  if t.nil? then exit(-1) end
  $saved_comments = Hash.new
  $vars_placeholders = Hash.new
  t = process(t)
  print t
end

def process(t)
  t = preprocess(t)
  t = translate_stuff(t)
  t = postprocess(t)
  return t
end

def translate_stuff(t)
  # kludge: def, if, ... are handled here, but assignments and for loops are handled in preprocess()
  t.gsub!(/^(\s*)def\s+([^:]+):/) {$1+"function "+$2}
  t.gsub!(/^(\s*)if\s+([^:]+):/) {$1+"if ("+$2+")"}
  t.gsub!(/^(\s*)else:/) {$1+"else"}
  t.gsub!(/^(\s*)(from|import).*/) {''}
  t.gsub!(/ and /,' && ')
  t.gsub!(/ or /,' || ')
  t.gsub!(/ not /,' ! ')
  return t
end

def postprocess(t)
  $saved_comments.each_pair { |key,value|
    t.gsub!(/#{key}/,value)
  }
  $vars_placeholders.each_pair { |key,value|
    vars = value.keys
    if vars.length>0 then
      decl = "var "+vars.join(',')+";\n"
    else
      decl = 'wugga'
    end
    t.gsub!(/#{key}/,decl)
  }
  t.gsub!(/ \/\*\s*"""/,"/*") # kludge for docstrings
  t.gsub!(/^((  )*) \/\*/) {$1+"/*"} # kludge to convert 2n+1 spaces before /* to 2n
  return t
end

def preprocess(t)
  t = docstrings_to_comments(t)
  # Protect text of comments from munging:
  t.gsub!(/#([^\n]*)$/) {d=digest($1); $saved_comments[d]=$1; '#'+digest($1); }
  # Combine long lines into single lines:
  t.gsub!(/([^\n]*)\\\s*\n([^\n]*)/) {"#{$1} #{$2}"}
  # Change tabs to 8 blanks:
  t.gsub!(/\t/,"        ")
  # Hand-translated lines are marked with #js comments.
  t.gsub!(/^( *)([^#\n]*)#js( *)([^\n]*)$/) {"#{$1}#{$4}"}
  # Translate comments:
  t.gsub!(/^([^#]*)#([^\n]*)$/) {"#{$1}/*#{$2} */"}
  # Split into lines:
  lines = t.split(/\n+/)
  # Curly braces around indented blocks:
  t2 = ''
  lines.push("___DELETEME___") # to trigger }'s at end
  indent_stack = [0]  # level of indentation at the start of the block
  opener_stack = [''] # keyword that started the block, e.g. "def"
  last_line = ''
  current_function_key = nil
  0.upto(lines.length-1) { |i|
    l = lines[i]
    l =~ /^( *)/
    ind = $1.length
    done = false
    if ind>indent_stack[-1] then
      done = true
      last_line =~ /([^ ]*)/ # first non-blank text is assumed to be keyword starting the block
      opener = process_opener($1)
      opener_stack.push(opener)
      if opener=='def' then
        current_function_key = "vars_placeholder"+digest(l+i.to_s)
      end
      indent_stack.push(ind)
      t2.gsub!(/;\n\Z/,'') # go back and erase semicolon and newline from previous line
      t2 = t2 + " {\n"
      if opener=='def' then
        t2 = t2+' '*ind+current_function_key
        $vars_placeholders[current_function_key] = Hash.new
      end
      t2 = t2 + translate_line(l,current_function_key) + ";\n"
    end
    while ind<indent_stack[-1]
      indent_stack.pop
      opener = opener_stack.pop
      t2 = t2 + (" "*indent_stack[-1]) + "}"
      if opener=='def' || opener=='' then t2=t2+"\n\n" else t2=t2+";\n" end
    end
    if !done then
      t2 = t2 + translate_line(l,current_function_key) + ";\n"
    end
    last_line = l
  }
  t = t2
  t.sub!(/___DELETEME___;?\n?/,'')
  # Bring semicolons and curly braces to the left of comments:
  t.gsub!(/(\/\*[^\n]*\*\/);$/) {"; #{$1}"}
  t.gsub!(/(\/\*[^\n]*\*\/) *{$/) {"{ #{$1}"}
  # No semicolon on a line consisting only of a comment:
  t.gsub!(/^( *);( *)(\/\*[^\n]*\*\/)( *)$/) {"#{$1+$2+$3+$4}"}
  # Done:
  return t
end

# Normally opener is whatever keyword opened the block, e.g., "def".
# But in a few cases, we get comments here. This happens, e.g., when include files have indented comments below
# defines.
def process_opener(opener)
  if opener=~/\/\*/ then return '' end
  return opener
end

# kludge: def, if, ... are handled in translate_stuff(), but assignments and for loops are handled in this
# routine, which gets called by preprocess()
def translate_line(l,current_function_key)
  if l=~/^\s*(\w[\w0-9,\[\]]*)\s*=/ then 
    return translate_assignment(l,current_function_key)
  end
  if l=~/for/ and l=~/range/ then
    return translate_for_loop(l,current_function_key)
  end
  return l
end

def translate_for_loop(l,current_function_key)
  # bug: doesn't preserve indentation, deletes comments; this should be handled using common logic, not cutting and
  #    pasting code from translate_assignment()
  # example: for j in range(3,len(x)):
  if l =~ /for\s+(\w+)\s+in\s+range\((.*)\):/ then
    var,r = [$1,$2]
    lo=0
    if r=~/(.*),(.*)/ then
      lo,hi = [$1,$2]
    else
      hi = r
    end
    return "for (var #{var}=#{lo}; #{var}<#{hi}; #{var}++)"
  end
end

def translate_assignment(l,current_function_key)
  l=~/^(\s*)(.*)\s*=(.*)/
  indentation,lhs,rhs = [$1,$2,$3]
  if lhs.nil? || rhs.nil? then return l end
  list_variables_to_declare(lhs,current_function_key)
  has_math = false
  if (rhs=~/(sin|cos|tan|exp|log|sqrt|abs|\*\*)/) then has_math=true end
  if has_math then
    rhs = translate_math(rhs)
    l = indentation+lhs + "=" + rhs
  end
  return l
end

# For a line like this
#     x = y+z /* blah */,
# the input is "y+z /* blah */", and the comment is maintained.
# 
def translate_math(e)
  debug = false
  if debug then print "e=#{e}, in translate_math\n" end
  if e=~/(.*[^\s])\s*\/\*(.*)\*\// then
    e,comment = $1,$2
  else
    comment = ''
  end
  e,err = translate_math2(e)
  if err!='' then comment=err+' '+comment end
  if comment!='' then e=e+' /*'+comment+'*/' end
  return e
end

# For a line like this
#     x = y+z[2] /* blah */,
# the input is "y+z[2]". If there is fancy math (basically just the exponentiation operator)
# that requires translate_maxima, use that. But in simpler cases, just do regexes, because
# (a) translate_maxima is super slow, and (b) translate_maxima reduces readability by adding
# lots of parens.
def translate_math2(e)
  err = ''
  if e=~/\*\*/ then # fancy math that requires translate_maxima
    e.gsub!(/\*\*/,'^') # translate exponentiation to maxima syntax
    e.gsub!(/^\s+/,'') # delete leading whitespace, which upsets it, not sure why
    # Protect array subscripts from translation, since translate_maxima can't handle them.
    # Also protect things like module.function(x), because maxima thinks . is multiplication.
    k = 0
    protect = Hash.new
    e.gsub!(/([a-zA-Z]\w*(\[[^\]]+\])+)/) {k=k+1; protect[k]=$1; "protectme#{k}"}
    e.gsub!(/(([a-zA-Z]\w*\.)+([a-zA-Z]\w*))/) {k=k+1; protect[k]=$1; "protectme#{k}"}
    e,err = translate_math_using_translate_maxima(e)
    e.gsub!(/protectme([0-9]+)/) {protect[$1.to_i]}
  else
    e.gsub!(/(sqrt|abs|sin|cos|tan|sinh|cosh|tanh|arcsing|acccosh|arctanh|exp|log)/) {"math.#{$1}"}
    #     ... see similar list in fns_to_prepend_with_math in translate_maxima.
  end
  return [e,err]
end

def translate_math_using_translate_maxima(e)
  debug = false
  file1 = "temp1_"+digest(e)+".mac"
  file2 = "temp2_"+digest(e)+".mac"
  File.open(file1,'w') { |f|
    f.print e
  }
  cmd = "python3 translate_maxima.py <#{file1} >#{file2}"
  err = ''
  if !system(cmd) then
    err = "cmd=#{cmd} failed, $?=#{$?}\n"
  end
  if debug then print "e=#{e}, ran command\n" end
  if err=='' then
    File.open(file2,'r') { |f|
      result = f.gets(nil).gsub(/\n$/,'')
      if debug then print "e=#{e} result=#{result}\n" end
      if ! result.nil? then 
        if result=~/^\^(.*)/ then
          err = $1
        else
          e = result
        end
      else
        err = "null result"
      end
    }
  end
  remove_temp_file(file1)
  remove_temp_file(file2)
  return [e,err]
end

def list_variables_to_declare(lhs,current_function_key)
  lhs.scan(/[a-zA-Z]\w*/) { |var|
    # Make a list of variables inside this function so that we can declare them.
    # In multiple assignment like x,y,z=array, loop over variables. In something like g[i]=...,
    # this also has the effect of declaring i, which is harmless.
    if !current_function_key.nil? then
      $vars_placeholders[current_function_key][var] = 1
    end
  }
end

def remove_temp_file(file)
  if FileTest.exist?(file) then FileUtils.rm(file) end
end

def docstrings_to_comments(t)
  lines = t.split(/\n+/)
  inside_docstring = false
  t2 = ''
  inside = false
  k = 1
  this_comment = ''
  lines.each { |l|
    done = false
    if l=~/( *)"""(.*)/ then
      done = true
      if not inside then
        this_comment = $2
        t2 = t2+$1+"/*"
        
      else
        this_comment = this_comment+$1
        d = digest(k.to_s)
        k = k+1
        $saved_comments[d]=this_comment
        this_comment = ''
        l = d+"*/"+$2
      end
      inside = !inside
    end
    if true then
      if !inside then
        t2 = t2+l+"\n"
      else
        this_comment = this_comment+l+"\n"
      end
    end
  }
  t2 = t2+"\n"
  return t2
end

def digest(s)
  return Digest::SHA256.hexdigest(s).gsub(/[a-f]/,'')
  # Filter out alphabetic hex characters to prevent any parser from accidentally thinking this is something
  # other than an atomic symbol, not to be tampered with.
end

main()
