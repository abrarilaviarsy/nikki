'use strict';
'require form';
'require view';
'require uci';
'require poll';
'require tools.nikki as nikki';

function renderStatus(running) {
    return updateStatus(E('input', {
        id: 'core_status',
        style: 'border: unset; font-style: italic; font-weight: bold;',
        readonly: ''
    }), running);
}

function updateStatus(element, running) {
    if (element) {
        element.style.color = running ? 'green' : 'red';
        element.value = running ? _('Running') : _('Not Running');
    }
    return element;
}

return view.extend({
    load: function() {
        return Promise.all([uci.load('nikki'), nikki.version(), nikki.status(), nikki.listProfiles()]);
    },
    render: function(data) {
        const subscriptions = uci.sections('nikki', 'subscription');
        const appVersion = data[1].app ?? '';
        const coreVersion = data[1].core ?? '';
        const running = data[2];
        const profiles = data[3];
        let m, s, o;

        m = new form.Map('nikki');

        // Status Section
        s = m.section(form.TableSection, 'status', _('<p><strong>📣 Status</strong></p>'));
        s.anonymous = true;
        o = s.option(form.Value, '_app_version', _('🔹App Version'));
        o.readonly = true;
        o.load = function() {
            return appVersion;
        };
        o.write = function() {};
        o = s.option(form.Value, '_core_version', _('🔹Core Version'));
        o.readonly = true;
        o.load = function() {
            return coreVersion;
        };
        o.write = function() {};
        o = s.option(form.DummyValue, '_core_status', _('🔹Core Status'));
        o.cfgvalue = function() {
            return renderStatus(running);
        };
        poll.add(function() {
            return L.resolveDefault(nikki.status()).then(function(running) {
                updateStatus(document.getElementById('core_status'), running);
            });
        });
        o = s.option(form.Button, 'reload');
        o.inputstyle = 'action';
        o.inputtitle = _('⟳ Reload Service');
        o.onclick = function() {
            return nikki.reload();
        };
        o = s.option(form.Button, 'restart');
        o.inputstyle = 'negative';
        o.inputtitle = _('⟳ Restart Service');
        o.onclick = function() {
            return nikki.restart();
        };
        o = s.option(form.Button, 'update_dashboard');
        o.inputstyle = 'positive';
        o.inputtitle = _('📤 Update Dashboard');
        o.onclick = function() {
            return nikki.updateDashboard();
        };
        o = s.option(form.Button, 'open_dashboard');
        o.inputtitle = _('👾 Open Dashboard');
        o.onclick = function() {
            return nikki.openDashboard();
        };

        // Config Section
        s = m.section(form.NamedSection, 'config', 'config', _('<p><strong>⚙️ App Config</strong></p>'));
        o = s.option(form.Flag, 'enabled', _('Enable'));
        o.rmempty = false;
        o = s.option(form.ListValue, 'profile', _('Choose Profile'));
        o.optional = true;
        for (const profile of profiles) {
            o.value('file:' + profile.name, _('File:') + profile.name);
        }
        for (const subscription of subscriptions) {
            o.value('subscription:' + subscription['.name'], _('Subscription:') + subscription.name);
        }
        o = s.option(form.Value, 'start_delay', _('Start Delay'));
        o.datatype = 'uinteger';
        o.placeholder = '0';
        o = s.option(form.Flag, 'scheduled_restart', _('Scheduled Restart'));
        o.rmempty = false;
        o = s.option(form.Value, 'cron_expression', _('Cron Expression'));
        o.retain = true;
        o.rmempty = false;
        o.depends('scheduled_restart', '1');
        o = s.option(form.Flag, 'test_profile', _('Test Profile'));
        o.rmempty = false;
        o = s.option(form.Flag, 'fast_reload', _('Fast Reload'));
        o.rmempty = false;
        o = s.option(form.Flag, 'core_only', _('Core Only'));
        o.rmempty = false;

        // Env Section (gabungan fitur upstream dan mod)
        s = m.section(form.NamedSection, 'env', 'env', _('Core Environment Variable Config'));

        // Safe Paths (tambahan dari upstream)
        o = s.option(form.DynamicList, 'safe_paths', _('Safe Paths'));
        o.load = function(section_id) {
            const val = this.super('load', section_id);
            return val ? val.split(':') : [];
        };
        o.write = function(section_id, formvalue) {
            this.super('write', section_id, formvalue ? formvalue.join(':') : '');
        };

        o = s.option(form.Flag, 'disable_safe_path_check', _('Disable Safe Path Check'));
        o.rmempty = false;

        o = s.option(form.Flag, 'disable_loopback_detector', _('Disable Loopback Detector'));
        o.rmempty = false;
        o = s.option(form.Flag, 'disable_quic_go_gso', _('Disable GSO of quic-go'));
        o.rmempty = false;
        o = s.option(form.Flag, 'disable_quic_go_ecn', _('Disable ECN of quic-go'));
        o.rmempty = false;
        o = s.option(form.Flag, 'skip_system_ipv6_check', _('Skip System IPv6 Check'));
        o.rmempty = false;

        return m.render();
    }
});