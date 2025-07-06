class ToolRegistry
  def self.available_tools
    tool_classes.map(&:openai_definition)
  end

  def self.tool_names
    tool_classes.map(&:tool_name)
  end

  def self.get_tool_definition(tool_name)
    tool_class = tool_classes.find { |klass| klass.tool_name == tool_name }
    tool_class&.openai_definition
  end

  def self.get_tool_class(tool_name)
    tool_classes.find { |klass| klass.tool_name == tool_name }
  end

  private

  def self.tool_classes
    # Auto-discover all tool classes in the Tools module
    @tool_classes ||= Tools.constants
      .map { |const_name| Tools.const_get(const_name) }
      .select { |const| const.is_a?(Class) && const < Tools::BaseTool && const != Tools::BaseTool }
  end
end
