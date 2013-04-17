require_relative 'test_case'

TestInit.configure_goo

class Task < Goo::Base::Resource
  model :task
  attribute :description, enforce: [ :existence, :unique]

  #one task can be linked to many projects
  attribute :project, enforce: [ :list, :project ] 

  def initialize(attributes = {})
    super(attributes)
  end
end

class Project < Goo::Base::Resource
  model :project
  attribute :name, enforce: [ :existence, :unique ]
  attribute :tasks, inverse: { on: Task, attribute: :project }
end



class TestInverse < TestCase
  def initialize(*args)
    super(*args)
  end

  def test_inverse_retrieval
    assert Project.range(:tasks) == Task
    assert Task.range(:project) == Project
    assert Goo.models[:task] == Task
    assert Goo.models[:project] == Project

    goo = Project.new(name: "Goo")
    Project.find("Goo").delete if goo.exist?
    assert goo.valid?
    goo.save
    assert goo.persistent?

    task1 = Task.new(description: "task1", project: [ goo ])
    Task.find("task1").delete if task1.exist?
    assert task1.valid?
    task1.save

    #task => project
    task = Task.find("task1", include: [ :project ])
    assert task.project.first.id == goo.id

    #do not allow to assign inverse properties
    assert_raises ArgumentError do
      goo.tasks = task
    end
  end
end
