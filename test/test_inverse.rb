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
    assert Project.attributes(:list).include?(:tasks)

    goo = Project.new(name: "Goo")
    Project.find("Goo").delete if goo.exist?
    assert goo.valid?
    goo.save
    assert goo.persistent?

    5.times do |i|
      task = Task.new(description: "task_#{i}", project: [ goo ])
      Task.find("task_#{i}").delete if task.exist?
      assert task.valid?
      task.save
    end

    #task => project
    5.times do |i|
      task = Task.find("task_#{i}", include: [ :project ])
      assert task.project.first.id == goo.id
    end

    #project => task
    project = Project.find("Goo", include: [ :tasks ])
    assert_equal(5, project.tasks.length)
    assert project.tasks.map { |x| x.id.to_s[33].to_i }.sort == [0,1,2,3,4]


    #do not allow to assign inverse properties
    assert_raises ArgumentError do
      project.tasks = Task.find("task_1")
    end

    3.times do |i|
      Task.find("task_#{i}").delete()
    end

    project = Project.find("Goo", include: [ :tasks ])
    assert_equal(2, project.tasks.length)
    Task.find("task_3").delete()
    Task.find("task_4").delete()
    assert_equal(2, project.tasks.length)
    assert project.tasks.map { |x| x.id.to_s[33].to_i }.sort == [3,4]
    project = Project.find("Goo", include: [ :tasks ])
    project.delete

  end
end
