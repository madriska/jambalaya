$LOAD_PATH.unshift File.dirname(__FILE__) + "/../lib"
require "jambalaya"

Jambalaya.generate("rbp_ch1.pdf") do

  title "CHAPTER 1", "Driving Code Through Tests"
  prose %{
    If you've done some Ruby--even a little bit--you have probably heard of 
    <i>test-driven development</i> (TDD). Many advocates present this software
    practice as the "secret key" to programming success.  However, it's still
    a lot of work to convince people that writing tests that are often longer
    than their implementation code can actually lower the total time spent on
    a particular project and increase overall efficiency.

    In my work, I've found most of the claims about the benefits of TDD to
    be true.  My code is better because I write tests that document the
    expected behaviors of my software while verifying that my code is meeting
    its requirements.  By writing automated test, I can be sure that once I
    narrow down the source of a bug and fix it, it'll never resurface without
    me knowing right away.   Because my tests are automated, I can hand my code
    off to others and mechanically assert my expectations, which does more for
    me than a handwritten specification ever could do.

    However, the important thing to take home from this is that automated
    testing is really no different than what we did before we discovered it.
    If you've ever tried to narrow down a bug with a print statement based on
    a conditional, you've already written a primitive form of unit test:
  }

  code <<-'EOS'
    if foo != "blah"
      puts "I expected 'blah' but foo contains #{foo}"
    end
  EOS

  prose %{
    If you've ever written an example to verify that a bug exists in an earlier
    version of code, but not in a later one, you've wrtitten something not at
    all far from the sorts of things you'll write through TDD.  The only
    difference is that one-off examples do not adequately account for the
    problems that can arise during integration with other modules.  This problem
    can become huge, and is one that unit testing frameworks handle quite well.

    Even if you already know a bit about testing and have been using it in your
    work, you might still feel like it doesn't come naturally.  You write tests because
    you see the long term benefits, but you usually write your code first.  It takes
    you a while to write your tests, because it seems like the code you wrote is
    difficult to pin down behavior-wise.  In the end, testing becomes a necessary
    evil.  You appreciate the safety net, but except for when you fail, you'd
    rather just focus on keeping your balance and moving forward.

    Masterful Rubyists will tell you otherwise, and for good reason.  Testing may
    be hard, but it truly does make your job of writing software easier.  This
    chapter will show you how to integrate automated testing into your workflow,
    without forcing you to relearn the troubleshooting skills you've already
    acquired.   By making use of the best practices discussed here, you'll be
    able to more easily see the merits of TDD in your own work.
  }

  section "A Quick Note on Testing Frameworks"

  prose %{
    Ruby provides a unit testing framework in its standard library called
    <i>minitest/unit</i>.  This library provides a user-level compatibility
    layer with the popular <i>test/unit</i> library, which has been fairly
    standard in the Ruby community for some time now.  There are significant
    differences between the <i>minitest/unit</i> and <i>test/unit</i>
    implementations, but as we won't be building low-level extension in
    this chapter, you can assume that the code here will work in both
    <i>minitest/unit</i> and <i>test/unit</i> without modifications.

    For what it's worth, I don't have a very strong preference when it comes to
    testing frameworks. I am using the <font name="mono">Test::Unit</font> API
    here because it is part of standard Ruby and because it is fundamentally
    easy to hack on and extend.  Many of the existing alternative testing
    frameworks are built on top of <font name="mono">Test::Unit</font>, and 
    you will almost cetainly need to have a working knowledge of it as a Ruby
    developer.   However, if you've been working with a non-compatible framework
    such as RSpec (<i><link href="http://rspec.info">http://rspec.info</link></i>),
    there is nothing wrong with that.  The ideas here should be mostly portable
    to your framework of choice.

    And now we can move on.  Before digging into the nuts and bolts of writing
    tests, we'll examine what it means for code to be easily testable, by looking
    at some real examples.
  }

  section "Designing for Testability"

  prose %{
    Describing testing with the phrase "Red, Green, Refactor" makes it seem
    fairly straightforward.  Most people interpret this as the process of
    writing some failing tests, getting those tests to pass, and then cleaning
    up the code without causing the tests to fail again.  This general
    assumption is exactly correct, but a common misconception is how much work
    needs to be done between each phase of this cycle.

    For example, if we try to solve our whole problem in one big chunk, add
    tests to verify that it works, then clean up our code, we end up with
    implement-ations that are very difficult to test, and even more challenging
    to refactor.  The following example illustraties just how bad the problems
    can get if you're not careful.  It's from some payroll management code
    I wrote in a hurry a couple years ago:
  }

  code(<<-'EOS', 7)
    def time_data_for_week(week_data,start,employee_id)
     
      data = Hash.new { |h,k| h[k] = Hash.new }
     
      %w[M T W TH F S].zip((0..6).to_a).each do |day,offset|
     
        date = (start + offset.days).beginning_of_day
      
        data[day][:lunch_hours] = LunchTime.find(:all, conditions:
          ["employee_id = ? and day between ? and ?",
              employee_id, date, date + 1.day - 1.second] ).inject(0) { |s,r|
                s + r.duration
              }
      
       times = [[:sick_hours , "Sick" ],
                [:personal_hours, "Personal"],
                [:vacation_hours, "Vacation"],
                [:other_hours, "Other" ]]
      
       times.each do |a,b|
         data[day][a] = OtherTime.find(:all, conditions:
           ["employee_id = ? and category = '#{b}' and date between ? and ?",
             employee_id, date, date + 1.day - 1.second] ).inject(0) { |s,r|
               s + r.hours
             }
       end
                                                                          
        d = week_data.find { |d,_| d == date }
      
        next unless d
                                             
        d = d[-1]
        data[day].merge!(
          regular_hours: d.inject(0) { |s,e|
            s + (e.end_time ? (e.end_time - e.start_time) / 3600 : 0)
          } - data[day][:lunch_hours],
          start_time: d.map { |e| e.start_time }.sort[0],
            end_time: d.map { |e| e.end_time }.compact.sort[-1]
        )
      
      end
     
      sums = Hash.new(0)
     
      data.each do |k,v|
        [:regular_hours, :lunch_hours, :sick_hours,
         :personal_hours, :vacation_hours, :other_hours].each { |h|
           sums[h] += v[h].to_f }
      end
       
      Table(:day,:start_time,:end_time,:regular_hours,:lunch_hours,
            :sick_hours,:personal_hours,:vacation_hours, :other_hours) do |t|
         %w[M T W TH F S].each { |d| t << {day: d}.merge(data[d]) }
         t << []
         t << { day: "<b>Totals</b>" }.merge(sums)
      end
    end 
  EOS

  prose %{
    When you look at the preceding example, did you have an easy time
    understanding it? If you didn't, you don't need to worry, because I can hardly
    remember what this code does, and I'm the one who wrote it. Though it is
    certainly possible to produce better code than this without employing TDD,
    it's actually quite difficult to produce something this ugly if you are writing
    your tests first. This is especially true if you manage to keep your iterations
    nice and tight. The very nature of test-driven development lends itself to breaking
    your code up into smaller, more simple chunks that can be easily interacted with.
    It's safe to say that we don't see any of those attributes here.

    Now that we've seen an example of what not to do, we can investigate the
    true benefits of TDD in the setting of a real project. What follows is the
    process that I went through while developing a simple feature for the Prawn PDF
    generation library. But first, we must embark on a small diversion.
  }

  aside("A Test::Unit Trick to Know About") do
    prose %{
      Usually, test cases written with <i>minitest/unit</i> or <i>test/unit</i> look like this:
    }

    code %{
      class MyThingieTest < Test::Unit::TestCase
     
        def test_must_be_empty
     
        end
     
        def test_must_be_awesome
     
        end
    
      end
    }

    prose %{
      But in all of the examples you'll see in the chapter, we'll be writing our tests
      look a little different.
    }
 end

 start_new_page

 aside("A Test::Unit Trick to Know About (continued)") do
    prose %{
     Instead of the previous code, we'll instead be working with something like this:
    }

    code %{
       class MyThingieTest < Test::Unit::TestCase
     
         must "be empty" do
     
         end
     
         must "be awesome" do
      
         end
      
       end
    }

    prose %{
      If you've used <font name="mono">Test::Unit</font> before, you might be
      a bit confused by the use  of the <font name="mono">must()</font> method
      here.  This is actually a custom addition largely based on the 
      <font name="mono">test()</font> method in the <i>activesupport</i> gem.
      All this code does is automatically generate  test methods for you,
      improving the clarity of our examples a bit.  You don't really need to
      worry about how this works, but for the curious, the implementation can be
      found at link.      

      We also discuss this in Chapter 3, <i>Mastering the Dynamic Toolkit</i>, as an example of
      how to make custom extensions to preexisting objects.  So although you only need to
      understand how <font style="mono">must()</font> is used here, you'll get a 
      chance  to see how it is built later on.
    }
  end

  prose %{
    Now that we've got that bit of logistics out of the way, we can move on.
    The code we are about to look at was originally part of Prawn's early support
    for inline stlying, which allows users to make use of bold and italic typefaces
    within a single string of text.  In practice, these strings look very similar to
    the most basic HTML markup:
  }

  code %{
    "This is a string with <b>bold, <i>bold italic</i></b> and <i>italic</i> text"
  }

  prose %{
    Although the details of how Prawn actually converts these strings into stylized
    text that can be properly rendered within a PDF docuemnt are somewhat gory, the
    process of breaking up the string and parsing out the style tags is quite
    straightforward.  We'll focus on this aspect of things, stepping through the
    design and development process until we end up with a simple function that
    behaves as follows:
  }

  start_new_page

  code(<<-'EOS', 7)
    >> StyleParser.process("Some <b>bold</b> and <i>italic</i> text")
    => ["Some ", "<b>", "bold", "</b>", " and ", "<i>", "italic", "</i>", " text"] 
  EOS

  prose %{ 
    And, yadda yadda yadda.  Typesetting concept proved.  Jambalaya FTW.
  }
end
