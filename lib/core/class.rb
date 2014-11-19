# size <= ssize *always* or something is severely wrong.
%s(defun __new_class_object (size superclass ssize)
  (let (ob i)
   (assign ob (malloc (mul size 4))) # Assumes 32 bit
   (assign i 6) # Skips the initial instance vars
 #  %s(printf "class object: %p (%d bytes) / Class: %p / super: %p / size: %d\n" ob size Class superclass ssize)
  (while (le i ssize) (do
       (assign (index ob i) (index superclass i))
       (assign i (add i 1))
  ))
  (while (lt i size) (do
       # Installing a pointer to a thunk to method_missing
       # that adds a symbol matching the vtable entry as the 
       # first argument and then jumps straight into __method_missing
       (assign (index ob i) (index __base_vtable i))
       (assign i (add i 1))
  ))
  (assign (index ob 0) Class)
  (assign (index ob 3) superclass)
# Sub-classes
  (assign (index ob 4) 0) 
  (if (eq superclass 0)
     (assign (index ob 5) 0)
     (do
        # Link in as subclass:
        (assign (index ob 5) (index superclass 4))
        (assign (index superclass 4) ob)
        )
)
  ob
))

# __set_vtable
#
# Set the vtable entry. If a subclass has *not*
# overridden a method, then propagate the override 
# downwards.
#
#  ---
#
# Most of this could be turned into pure Ruby. The
# code is roughly equivalent to this "pseudo-Ruby":
#
#   p = vtable.subclasses
#   while p
#      if p[off] == vtable[off]; __set_vtable(p,off,ptr); end
#      p = p.next_sibling
#   end
#   vtable[off] = ptr
#
%s(defun __set_vtable (vtable off ptr)
   (let (p) 
    (assign p (index vtable 4)) 
    (while (sexp p) 
       (do 
          (if (eq (index p off) (index vtable off)) (__set_vtable p off ptr))
          (assign p (index p 5))
       )
    )
  (assign (index vtable off) ptr)
))




class Class

  def new *rest
    # @instance_size is generated by the compiler. YES, it is meant to be
    # an instance var, not a class var
    size = @instance_size
    %s(assign ob (malloc (mul size 4)))
    %s(assign (index ob 0) self)
    ob.initialize(*rest)
    ob
  end

  def name
    %s(__get_string @name)
  end

  def to_s
    name
  end

  def inspect
    name
  end

  def !=  other
    !(self == other)
  end

  # FIXME: The "if" is a workaround due to bootstrap
  # issues which get any classes that get initialized before
  # Object set up with the superclass pointer set to 0 at
  # the moment. A proper fix is needed
  def superclass
    %s(if (index self 3) (index self 3) Object)
  end

  # FIXME
  # &block will be a "bare" %s(lambda) (that needs to be implemented),
  # define_method needs to attach that to the vtable (for now) and/or
  # to a hash table for "overflow" (methods lacking vtable slots).
  # This requires a painful decision:
  #
  # - To type-tag Symbol or not to type-tag
  #
  # It also means adding a function to look up a vtable offset from
  # a symbol, which effectively means a simple hash table implementation
  #
  def define_method sym, &block
    %s(printf "define_method %s\n" (callm (callm sym to_s) __get_raw))
  end

  # FIXME: Should handle multiple symbols
  def attr_accessor sym
    attr_reader sym
    attr_writer sym
  end
  
  def attr_reader sym
    %s(printf "attr_reader %s\n" (callm (callm sym to_s) __get_raw))
    define_method sym do
#       %s(ivar self sym) # FIXME: Create the "ivar" s-exp directive.
    end
  end

  def attr_writer sym
    %s(printf "attr_writer %s\n" (callm (callm sym to_s) __get_raw))
    # FIXME: Ouch: Requires both String, string interpolation and String#to_sym to
    # be implemented on top of define_method and "ivar"
    define_method "#{sym.to_s}=".to_sym do |val|
#      %s(assign (ivar self sym) val)
    end
  end

  def __send__ sym, *args
    %s(printf "WARNING: __send__ bypassing vtable (name not statically known at compile time) not yet implemented.\n")
    %s(if sym (printf "WARNING:    Method: '%s'\n" (callm (callm sym to_s) __get_raw)))
    %s(printf "WARNING:    symbol address = %p\n" sym)
    %s(printf "WARNING:    self = %p\n" self)
    %s(printf "WARNING:    class '%s'\n" (callm (callm (callm self class) name) __get_raw))
  end

  # FIXME: Belongs in Kernel

end

%s(assign (index Class 0) Class)
%s(assign (index Class 2) "Class")

