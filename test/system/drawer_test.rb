require "application_system_test_case"

class DrawerTest < ApplicationSystemTestCase
  setup do
    @user  = users(:one)
    @essay = essays(:one)
    sign_in @user
  end

  test "drawer panel is off-screen before open" do
    visit essay_path(@essay)

    info = page.evaluate_script(<<~JS)
      (function() {
        const drawer = document.querySelector('[data-reader-settings-target="drawer"]');
        const r = drawer.getBoundingClientRect();
        return { top: r.top, bottom: r.bottom, height: r.height, vp_h: window.innerHeight, transform: getComputedStyle(drawer).transform };
      })()
    JS

    # Panel should be below the viewport (translated off-screen by its own height)
    assert info["top"] >= info["vp_h"], "Drawer should be off-screen before open, but top=#{info["top"]} vp=#{info["vp_h"]}"
  end

  test "drawer panel appears as compact bottom sheet when opened" do
    visit essay_path(@essay)

    find("[data-action='reader-settings#openDrawer']").click
    sleep 0.4  # wait for 300ms transition

    info = page.evaluate_script(<<~JS)
      (function() {
        const drawer  = document.querySelector('[data-reader-settings-target="drawer"]');
        const scrim   = document.querySelector('[data-reader-settings-target="scrim"]');
        const inner   = drawer.firstElementChild;
        const vp      = { w: window.innerWidth, h: window.innerHeight };

        const dr = drawer.getBoundingClientRect();
        const sr = scrim.getBoundingClientRect();
        const ir = inner ? inner.getBoundingClientRect() : {};

        // find any tall descendants
        const tallKids = Array.from(drawer.querySelectorAll('*')).map(el => {
          const r = el.getBoundingClientRect();
          const cls = el.getAttribute('class') || '';
          return { tag: el.tagName, cls: cls.substring(0,60), h: Math.round(r.height) };
        }).filter(e => e.h > 80).slice(0, 10);

        // check for transforms on ancestor chain
        let anc = drawer.parentElement;
        const transformedAncestors = [];
        while (anc && anc !== document.body) {
          const t = getComputedStyle(anc).transform;
          const cls = anc.getAttribute('class') || '';
          if (t && t !== 'none') transformedAncestors.push({ tag: anc.tagName, cls: cls.substring(0,40), transform: t });
          anc = anc.parentElement;
        }

        const btn = drawer.querySelector('button[data-mode]');
        const btnParent = btn ? btn.parentElement : null;
        const btnGP     = btnParent ? btnParent.parentElement : null;
        const btnGGP    = btnGP ? btnGP.parentElement : null;

        return {
          viewport:       vp,
          drawer_top:     dr.top,
          drawer_bottom:  dr.bottom,
          drawer_height:  dr.height,
          drawer_classes: drawer.className,
          inner_height:   ir.height || 'n/a',
          scrim_top:      sr.top,
          scrim_height:   sr.height,
          scrim_opacity:  parseFloat(getComputedStyle(scrim).opacity),
          scrim_pointer:  getComputedStyle(scrim).pointerEvents,
          tall_kids:      tallKids,
          transformed_ancestors: transformedAncestors,
          btn_computed_height:   btn ? getComputedStyle(btn).height : 'n/a',
          btn_computed_align_self: btn ? getComputedStyle(btn).alignSelf : 'n/a',
          seg_computed_height:   btnParent ? getComputedStyle(btnParent).height : 'n/a',
          seg_computed_display:  btnParent ? getComputedStyle(btnParent).display : 'n/a',
          seg_computed_align_items: btnParent ? getComputedStyle(btnParent).alignItems : 'n/a',
          row_computed_height:   btnGP ? getComputedStyle(btnGP).height : 'n/a',
          row_computed_align_items: btnGP ? getComputedStyle(btnGP).alignItems : 'n/a',
          content_computed_height: btnGGP ? getComputedStyle(btnGGP).height : 'n/a',
          content_computed_display: btnGGP ? getComputedStyle(btnGGP).display : 'n/a',
          content_computed_align_items: btnGGP ? getComputedStyle(btnGGP).alignItems : 'n/a',
        };
      })()
    JS

    vp_h = info["viewport"]["h"]
    puts "\n=== Drawer debug ==="
    puts "Viewport: #{info["viewport"].inspect}"
    puts "Drawer: top=#{info["drawer_top"].round(1)} bottom=#{info["drawer_bottom"].round(1)} height=#{info["drawer_height"].round(1)}"
    puts "Scrim:  top=#{info["scrim_top"].round(1)} height=#{info["scrim_height"].round(1)} opacity=#{info["scrim_opacity"]} pointer-events=#{info["scrim_pointer"]}"
    puts "Drawer classes: #{info["drawer_classes"]}"
    puts "Inner content: height=#{info["inner_height"]}"
    puts "Tall descendants: #{info["tall_kids"].map { |k| "#{k["tag"]}(#{k["h"]}px)" }.join(", ")}"
    puts "Button computed: height=#{info["btn_computed_height"]} align-self=#{info["btn_computed_align_self"]}"
    puts "Seg ctrl: display=#{info["seg_computed_display"]} height=#{info["seg_computed_height"]} align-items=#{info["seg_computed_align_items"]}"
    puts "View row: height=#{info["row_computed_height"]} align-items=#{info["row_computed_align_items"]}"
    puts "Content div: display=#{info["content_computed_display"]} height=#{info["content_computed_height"]} align-items=#{info["content_computed_align_items"]}"
    puts "===================="

    # Scrim must cover the full viewport
    assert_in_delta 0, info["scrim_top"], 1, "Scrim top should be 0, got #{info["scrim_top"]}"
    assert_in_delta vp_h, info["scrim_height"], 2, "Scrim height should equal viewport height, got #{info["scrim_height"]}"
    assert_in_delta 1.0, info["scrim_opacity"], 0.05, "Scrim should be fully opaque"
    assert_equal "auto", info["scrim_pointer"], "Scrim should accept pointer events"

    # Panel must be visible at the bottom — not full-height
    assert info["drawer_bottom"].round <= vp_h + 2, "Drawer bottom should be at viewport bottom, got #{info["drawer_bottom"]}"
    assert info["drawer_top"] > 0, "Drawer top should be above 0 (not full-height), got #{info["drawer_top"]}"
    assert info["drawer_height"] < vp_h * 0.7, "Drawer should be less than 70% of viewport height, got #{info["drawer_height"]} vs viewport #{vp_h}"
    assert info["drawer_height"] > 100, "Drawer should have meaningful height, got #{info["drawer_height"]}"
  end
end
