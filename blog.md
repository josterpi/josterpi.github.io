---
layout: default
title: Blog | Jeremy Osterhouse
---

<div class="home">
  {% for post in site.posts limit: 5 %}
    {% include blog-post.html post=post %}
  {% endfor %}

  {% if site.posts.size > 5 %}
    <h3>More posts</h3>
    <ul class="post-title-list">
      {% for post in site.posts offset: 5 %}
        <li><a class="post-link" href="{{ post.url | prepend: site.baseurl }}">{{ post.title }}</a></li>
      {% endfor %}
    </ul>
  {% endif %}
</div>
