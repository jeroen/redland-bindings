require 'rdf'
require 'rdf/uri'

module Redland
  class Node
    attr_reader :node
    
    @@node_types = {0 =>'NODE_TYPE_UNKNOWN',
                    1 =>'NODE_TYPE_RESOURCE',
                    2 =>'NODE_TYPE_LITERAL',
                    4 =>'NODE_TYPE_BLANK'}

    # Create an RDF Node
    # 
    # Resource or property node creation
    # n1 = Node.new(Uri.new("http://example.com/foo"))
    #
    # String literal node creation
    # n2 = Node.new("foo")
    def initialize(arg=nil)
      if arg.class == String
        temp = arg
        arg = {}
        arg[:literal]= temp
        @node = self.node_from_hash(arg)
      elsif arg.class == Hash
        @node = node_from_hash(arg)
      else
        @node = Node.ensure(arg)
      end
      raise RedlandError.new("Node construction failed") if not @node
      ObjectSpace.define_finalizer(self,Node.create_finalizer(@node))
    end

    def node_from_hash(hash)
      h = {:blank,:uri_string}
      if hash.key?(:blank)
        node = Redland.librdf_new_node_from_blank_identifier($world.world,hash[:blank])
      end
      if hash.key?(:from_object)
        if hash.key?(:do_not_copy)
          node = hash[:from_object]
        else
          node = Redland.librdf_new_node_from_node(hash[:from_object])
        end
      end
      
      if hash.key?(:uri_string)
        node = Redland.librdf_new_node_from_uri_string($world.world,hash[:uri_string])
      end
      if hash.key?(:literal)
        node = node_from_literal(hash)
      end
      return node
    end

    def node_from_literal(hash)
      xml_language = hash.key?(:xml_language) ? hash[:xml_language] : ""
      wf_xml = hash.key?(:wf_xml?) ? 1 : 0
      if hash.key?(:datatype)
        datatype = hash[:datatype]
        node = Redland.librdf_new_node_from_typed_literal($world.world,hash[:literal],xml_language,datatype.uri)
      else
        node = Redland.librdf_new_node_from_literal($world.world,hash[:literal],xml_language,wf_xml)
      end
      return node
    end

    def Node.bnode(id=nil)
      @node = Redland.librdf_new_node_from_blank_identifier($world.world,id)
    end

    def Node.create_finalizer(node)
      proc {|id| Redland::librdf_free_node(node) }
    end

    def Node.anon(id)
      self.initialize()
      super(id)
      @node = Redland.librdf_new_node_from_blank_identifier($world.world,id)
    end

    # Return true if node is a literal
    def literal?
      return (Redland.librdf_node_is_literal(self.node) !=0)
    end

    # Return true if node is a resource with a URI
    def resource?
      return (Redland.librdf_node_is_resource(self.node) !=0)
    end

    # Return true if node is a blank node
    def blank?
      return (Redland.librdf_node_is_blank(self.node) !=0)
    end

    def ==(other)
      return (Redland.librdf_node_equals(self.node,other.node) != 0)
    end

    def to_s
      return Redland.librdf_node_to_string(self.node)
    end

    def node_type()
      return @@node_types[Redland.librdf_node_get_type(self.node)]
    end
    
    # return a copy of the internal uri
    def uri
      if self.resource?
        return Uri.new(Redland.librdf_node_get_uri(self.node))
      else
        raise NodeTypeError.new("Can't get URI for node type %s" % self.node_type() )
      end
    end

    def literal
      unless self.literal?
        raise NodeTypeError.new("Can't get literal value for node type %s" % self.node_type)
      end
      return Literal.from_node(self.node)
    end

    def blank_identifier()
      unless self.blank?
        raise NodeTypeError.new("Can't get blank identifier for node type %s" % self.node_type)
      else
        return Redland.librdf_node_get_blank_identifier(self.node)
      end
    end

    def Node.ensure(node)
      case node
      when Node
        my_node = Redland.librdf_new_node_from_node(node.node)
      when SWIG::TYPE_p_librdf_node
        my_node = Redland.librdf_new_node_from_node(node)
      when Uri
        my_node = Redland.librdf_new_node_from_uri($world.world,node.uri)
      when URI
        my_node = Redland.librdf_new_node_from_uri_string($world.world,node.to_s)
      else
        my_node = nil
      end
      return my_node
    end

  end

  class BNode < Node

    def initialize(id=nil)
      @node = Redland.librdf_new_node_from_blank_identifier($world.world,id)
      if not @node then raise RedlandError.new("Node construction failed")end
      ObjectSpace.define_finalizer(self,Node.create_finalizer(@node))
    end
    
  end

  class Namespace < Node

    def initialize(namespace)
      super(:uri_string=>namespace)
      @nodecache = {}
    end

    def [](item)
      return self.the_node(item)
    end

    def the_node(localName)
      if not @nodecache.member? localName
        @nodecache[localName] = Node.new(:uri_string=>self.uri.to_s + localName)
      end
      return @nodecache[localName]
    end
    
  end

  class Literal < Node
    include Redland
    
    attr_reader :value,:language

    def initialize(str,lang=nil,uri=nil,is_xml=false)
      @value = str
      @language = lang
      is_xml = is_xml==true ? 1 : 0
      if uri
        @node = Redland.librdf_new_node_from_typed_literal($world.world,value,lang,uri.uri)
      else
        @node = Redland.librdf_new_node_from_literal($world.world,value,lang,is_xml)
      end

      raise RedlandError.new("Node construction failed") if not @node
      ObjectSpace.define_finalizer(self,Node.create_finalizer(@node))
    end

    def Literal.from_node(node)
      lang = Redland.librdf_node_get_literal_value_language(node) if Redland.librdf_node_get_literal_value_language(node)
      str = Redland.librdf_node_get_literal_value(node)
      hash_uri = Redland.librdf_node_get_literal_value_datatype_uri(node)
      hash_uri = Uri(Redland.librdf_uri_to_string(hash_uri)) if hash_uri
      return Literal.new(str,lang,hash_uri)
    end

    def Literal.from_xml(str,lang=nil)
      return Literal.new(str,lang,nil,true)
    end
  end
end #Redland
