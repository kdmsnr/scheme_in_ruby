#!/usr/bin/env ruby

DEBUG = false

$primitive_fun_env = {
  :+  => [:prim, lambda{|x, y| x + y}],
  :-  => [:prim, lambda{|x, y| x - y}],
  :*  => [:prim, lambda{|x, y| x * y}],
  :>  => [:prim, lambda{|x, y| x > y}],
  :>= => [:prim, lambda{|x, y| x >= y}],
  :<  => [:prim, lambda{|x, y| x <  y}],
  :<= => [:prim, lambda{|x, y| x <= y}],
  :== => [:prim, lambda{|x, y| x == y}],
}

$boolean_env = {
  :true => true, :false => false
}

$list_env = {
  :nil   => [],
  :null? => [:prim, lambda{|list| null?(list)}],
  :cons  => [:prim, lambda{|a, b| cons(a, b)}],
  :car   => [:prim, lambda{|list| car(list)}],
  :cdr   => [:prim, lambda{|list| cdr(list)}],
  :list  => [:prim, lambda{|*list| list(*list)}],
}

$global_env = [$list_env, $primitive_fun_env, $boolean_env]

def cons(a, b)
  if not list?(b)
    raise "sorry, we haven't implemented yet..."
  else
    [a] + b
  end
end

def null?(list)
  list == []
end

def car(list)
  list[0]
end

def cdr(list)
  list[1...list.length]
end

def list(*list)
  list
end

def parse(exp)
  program = exp.strip().
    gsub(/set!/, 'setq').
    gsub(/[a-zA-Z\+\-\*><=][0-9a-zA-Z\+\-=*]*/, ':\\0').
    gsub(/\s+/, ', ').
    gsub(/\(/, '[').
    gsub(/\)/, ']')
  log(program)
  eval(program)
end

def apply(fun, args)
  log "apply fun:#{fun}, args:#{pp(args)}"
  if primitive_fun?(fun)
    apply_primitive_fun(fun, args)
  else
    lambda_apply(fun, args)
  end
end

def list? exp
  Array === exp
end

def immediate_val? exp
  num?(exp) 
end

def num? exp
  Numeric === exp
end

def primitive_fun? exp
  exp[0] == :prim
end

def lambda?(exp)
  exp[0] == :lambda
end

def make_closure(exp, env)
  parameters, body = exp[1], exp[2]
  [:closure, parameters, body, env]
end

def closure_to_parameters_body_env(closure)
  [closure[1], closure[2], closure[3]]
end

def lambda_apply(closure, args)
  parameters, body, env = closure_to_parameters_body_env(closure)
  new_env = extend_env(parameters, args, env)
  _eval(body, new_env)
end

def extend_env(parameters, args, env)
  alist = parameters.zip(args)
  h = Hash.new
  alist.each { |k, v| h[k] = v }
  [h] + env
end

def extend_env_q(parameters, args, env)
  alist = parameters.zip(args)
  h = Hash.new
  alist.each { |k, v| h[k] = v }
  env.unshift(h)
end


def lookup_var(var, env)
  #    log "lookup_var: var:#{var}, env: #{env}"
  val = nil
  env.each do |alist|  
    if alist.key?(var)
      val = alist[var]
      break 
    end
  end
  #    log "lookup_var: var:#{var}, val:#{val}"
  if val == nil
    raise "couldn't find value to variables:'#{var}'"
  end
  val
end  

def lookup_var_ref(var, env)
  val = nil
  env.each do |alist|  
    if alist.key?(var)
      val = alist
      break 
    end
  end
  val
end  

def define_with_parameter?(exp)
  list?(exp[1])
end

def define_with_parameter_var_val(exp)
  var = car(exp[1])
  parameters, body = cdr(exp[1]), exp[2]
  val = [:lambda, parameters, body]
  [var, val]
end

def eval_define(exp, env)
  if define_with_parameter?(exp)
    var, val = define_with_parameter_var_val(exp)
  else
    var, val = define_var_val(exp)
  end
  var_ref = lookup_var_ref(var, env)
  if var_ref != nil
    var_ref[var] = _eval(val, env)
  else
    extend_env_q([var], [_eval(val, env)], env)
  end
  nil
end

def define_var_val(exp)
  [exp[1], exp[2]]
end

def apply_primitive_fun(fun, args)
  fun_val = fun[1]
  fun_val[*args]
end

def special_form?(exp)
  lambda?(exp) or 
    let?(exp) or 
    letrec?(exp) or 
    if?(exp) or 
    cond?(exp) or 
    define?(exp) or 
    quote?(exp) or 
    setq?(exp)
end

def quote?(exp)
  exp[0] == :quote
end

def define?(exp)
  exp[0] == :define
end

def cond?(exp)
  exp[0] == :cond
end

def let?(exp)
  exp[0] == :let
end

def letrec?(exp)
  exp[0] == :letrec
end

def if?(exp)
  exp[0] == :if
end

def eval_lambda(exp, env)
  make_closure(exp, env)
end

def eval_special_form(exp, env)
  if lambda?(exp)
    eval_lambda(exp, env)
  elsif let?(exp)
    eval_let(exp, env)
  elsif letrec?(exp)
    eval_letrec(exp, env)
  elsif if?(exp)
    eval_if(exp, env)
  elsif cond?(exp)
    eval_cond(exp, env)
  elsif define?(exp)
    eval_define(exp, env)
  elsif quote?(exp)
    eval_quote(exp, env)
  elsif setq?(exp)
    eval_setq(exp, env)
  end
end

def eval_setq(exp, env)
  var, val = setq_to_var_val(exp)
  var_ref = lookup_var_ref(var, env)
  if var_ref != nil
    var_ref[var] = _eval(val, env)
  else
    raise "undefined variable:'#{var}'"    
  end
  nil
end

def setq_to_var_val(exp)
  [exp[1], exp[2]]
end

def setq? exp
  exp[0] == :setq
end

def eval_quote(exp, env)
  car(cdr(exp))
end

def if_to_cond_true_false(exp)
  [exp[1], exp[2], exp[3]]
end

def eval_if(exp, env)
  cond, true_clause, false_clause = if_to_cond_true_false(exp)
  if _eval(cond, env)
    _eval(true_clause, env)
  else
    _eval(false_clause, env)
  end
end

def eval_cond(exp, env)
  if_exp = cond_to_if(cdr(exp))
  eval_if(if_exp, env)
end

def cond_to_if(cond_exp)
  if cond_exp == []
    ''
  else
    e = car(cond_exp)
    p, c = e[0], e[1]
    if p == :else
      p = :true
    end
    [:if, p, c, cond_to_if(cdr(cond_exp))]
  end  
end

def eval_let(exp, env)
  parameters, args, body = let_to_parameters_args_body(exp)
  new_exp = [[:lambda, parameters, body]] + args
  _eval(new_exp, env)
end

def eval_letrec(exp, env)
  parameters, args, body = letrec_to_parameters_args_body(exp)
  tmp_env = Hash.new
  parameters.each do |parameter| 
    tmp_env[parameter] = :dummy
  end
  ext_env = extend_env(tmp_env.keys(), tmp_env.values(), env)
  args_val = eval_list(args, ext_env)
  set_extend_env_q(parameters, args_val, ext_env)
  new_exp = [[:lambda, parameters, body]] + args
  _eval(new_exp, ext_env)
end

def set_extend_env_q(parameters, args_val, ext_env)
  parameters.zip(args_val).each do |parameter, arg_val|
    ext_env[0][parameter] = arg_val
  end
end

def let_to_parameters_args_body(exp)
  [exp[1].map{|e| e[0]}, exp[1].map{|e| e[1]}, exp[2]]
end

def letrec_to_parameters_args_body(exp)
  let_to_parameters_args_body(exp)
end

def _eval(exp, env)
  log("eval :exp: #{pp(exp)}, env:#{pp(env)}")
  if not list?(exp)
    if immediate_val?(exp)
      exp
    else 
      lookup_var(exp, env)
    end
  else
    if special_form?(exp)
      eval_special_form(exp, env)
    else
      fun = _eval(car(exp), env)
      args = eval_list(cdr(exp), env)
      apply(fun, args)
    end
  end
end

def eval_list(exp, env)
  exp.map{|e| _eval(e, env)}
end    

def pp(exp)
  if Symbol === exp or num?(exp)
    exp.to_s
  elsif exp == nil
    'nil'
  elsif (Array === exp) and (exp[0] == :closure)
    parameter, body, env = exp[1], exp[2], exp[3]
    "(closure #{pp(parameter)} #{pp(body)})"
  elsif lambda?(exp)
    parameters, body = exp[1], exp[2]
    "(lambda #{pp(parameters)} #{pp(body)})"
  elsif Hash === exp
    if exp == $primitive_fun_env
      '*prinmitive_fun_env*'
    elsif exp == $boolean_env
      '*boolean_env*'
    elsif exp == $list_env
      '*list_env*'
    else
      s = "{" 
      exp.each{|k, v| s+= pp(k) + ":" + pp(v) + ", " }
      s[0..s.length-3] + "}"
    end
  elsif Array === exp
    s = "("
    exp.each{|e| s+= pp(e)+" " }
    s[0..s.length-2] + ")"
  else 
    exp.to_s
  end
end

def repl
  command_char = '>>> '
  print command_char
  while line = STDIN.gets
    val = _eval(parse(line), $global_env)
    puts pp(val)
    print command_char
  end
end

def log(message)
  if (DEBUG)
    puts message
  end
end

def assert(tested, expected)
  if expected != tested
    raise "test failed. expencted:'#{expected}', but test:'#{tested}'"
  end
end

$programs_expects =
  [
   # test let
   [[:let, [[:x, 2], [:y, 3]], [:+, :x, :y]],
    5],
   [[:let, [[:x, 2] , [:y, 3]], [[:lambda, [:x, :y], [:+, :x, :y]], :x, :y]],
     5],
   [[:let, [[:add, [:lambda, [:x, :y], [:+, :x, :y]]]], [:add, 2, 3]],
    5],
   # test if
   [[:if, [:>, 3, 2], 1, 0],
    1],
   # test letrec
   [[:letrec, 
     [[:fact,
       [:lambda, [:n], [:if, [:<, :n, 1], 1, [:*, :n, [:fact, [:-, :n, 1]]]]]]], 
     [:fact, 3]], 
    6],
   # test cond 
   [[:cond, 
    [[:<, 2, 1], 0],
    [[:<, 2, 1], 1],
    [:else, 1]], 
    1],
   # test define
   [[:define, [:length, :list], 
    [:if, [:null?, :list], 0, 
     [:+, [:length, [:cdr, :list]], 1]]], 
    nil],
   [[:length, [:list, 1, 2]],
    2],
   [[:define, [:id, :x], :x],
    nil],
   [[:id, 3],
    3],
   [[:define, :x, [:lambda, [:x], :x]],
    nil],
   [[:x, 3],
    3],
   [[:define, :x, 5],
    nil],
   [:x,
    5],
   # test setq
   [[:let, [[:x, 1]],
     [:let, [[:dummy, [:setq, :x, 2]]],
      :x]], 2],
   # test list
   [[:list, 1],
    [1]],
   # test repl
   [parse('(define (length list) (if  (null? list) 0 (+ (length (cdr list)) 1)))'),
    nil],
   [parse('(length (list 1 2 3))'), 
    3],
   [parse('(letrec ((fact (lambda (n) (if (< n 1) 1 (* n (fact (- n 1))))))) (fact 3))'),
    6],
   [parse('(let ((x 1)) (let ((dummy (set! x 2))) x))'),
    2],
   # test fixed point
   # fact(0) = 1
   [[:let, 
     [[:fact,
       [:lambda, [:n], [:if, [:<, :n, 1], 1, [:*, :n, [:fact, [:-, :n, 1]]]]]]], 
     [:fact, 0]], 1],
   # fact(1) = 1
   [[:let, 
     [[:fact,
       [:lambda, [:n], 
        [:if, [:<, :n, 1], 1, 
         [:*, :n, 
          [:let, 
           [[:fact,
             [:lambda, [:n], [:if, [:<, :n, 1], 1, [:*, :n, [:fact, [:-, :n, 1]]]]]]],
           [:fact, [:-, :n, 1]]]]]]]], 
     [:fact, 1]], 1],
   # fact(2) = 2
   [[:let, 
     [[:fact,
       [:lambda, [:n], 
        [:if, [:<, :n, 1], 1, 
         [:*, :n, 
          [:let, 
           [[:fact,
             [:lambda, [:n], [:if, [:<, :n, 1], 1, [:*, :n, [:fact, [:-, :n, 1]]]]]]],
           [:let, 
            [[:fact,
              [:lambda, [:n], [:if, [:<, :n, 1], 1, [:*, :n, [:fact, [:-, :n, 1]]]]]]],
            
            [:fact, [:-, :n, 1]]]]]]]]], 
     [:fact, 2]], 2],
  ]

def test
  $programs_expects.each do |exp, expect| 
    log("test: exp:#{pp(exp)}, expect:#{pp(expect)}, result:#{pp(_eval(exp, $global_env))}")
    assert(_eval(exp, $global_env), expect)
  end
end

test

