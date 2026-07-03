// Populate the sidebar
//
// This is a script, and not included directly in the page, to control the total size of the book.
// The TOC contains an entry for each page, so if each page includes a copy of the TOC,
// the total size of the page becomes O(n**2).
class MDBookSidebarScrollbox extends HTMLElement {
    constructor() {
        super();
    }
    connectedCallback() {
        this.innerHTML = '<ol class="chapter"><li class="chapter-item "><a href="index.html">Home</a></li><li class="chapter-item affix "><li class="part-title">src</li><li class="chapter-item "><a href="src/base/index.html">❱ base</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/base/ERC20.sol/abstract.ERC20.html">ERC20</a></li></ol></li><li class="chapter-item "><a href="src/interfaces/index.html">❱ interfaces</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/interfaces/IAllowanceTransfer.sol/interface.IAllowanceTransfer.html">IAllowanceTransfer</a></li><li class="chapter-item "><a href="src/interfaces/IDAIPermit.sol/interface.IDAIPermit.html">IDAIPermit</a></li><li class="chapter-item "><a href="src/interfaces/IEIP712.sol/interface.IEIP712.html">IEIP712</a></li><li class="chapter-item "><a href="src/interfaces/IERC20.sol/interface.IERC20.html">IERC20</a></li><li class="chapter-item "><a href="src/interfaces/IERC20Permit.sol/interface.IERC20Permit.html">IERC20Permit</a></li><li class="chapter-item "><a href="src/interfaces/IMulticall_v4.sol/interface.IMulticall_v4.html">IMulticall_v4</a></li><li class="chapter-item "><a href="src/interfaces/ISignatureTransfer.sol/interface.ISignatureTransfer.html">ISignatureTransfer</a></li><li class="chapter-item "><a href="src/interfaces/IWETH9.sol/interface.IWETH9.html">IWETH9</a></li><li class="chapter-item "><a href="src/interfaces/I_TTSwap_Market.sol/interface.I_TTSwap_Market.html">I_TTSwap_Market</a></li><li class="chapter-item "><a href="src/interfaces/I_TTSwap_Market.sol/struct.S_ProofState.html">S_ProofState</a></li><li class="chapter-item "><a href="src/interfaces/I_TTSwap_Market.sol/struct.S_GoodState.html">S_GoodState</a></li><li class="chapter-item "><a href="src/interfaces/I_TTSwap_Market.sol/struct.S_GoodTmpState.html">S_GoodTmpState</a></li><li class="chapter-item "><a href="src/interfaces/I_TTSwap_Market.sol/struct.S_ProofKey.html">S_ProofKey</a></li><li class="chapter-item "><a href="src/interfaces/I_TTSwap_Token.sol/interface.I_TTSwap_Token.html">I_TTSwap_Token</a></li><li class="chapter-item "><a href="src/interfaces/I_TTSwap_Token.sol/struct.s_share.html">s_share</a></li><li class="chapter-item "><a href="src/interfaces/I_TTSwap_Token.sol/struct.s_proof.html">s_proof</a></li></ol></li><li class="chapter-item "><a href="src/libraries/index.html">❱ libraries</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/libraries/L_Currency.sol/library.L_CurrencyLibrary.html">L_CurrencyLibrary</a></li><li class="chapter-item "><a href="src/libraries/L_Currency.sol/constants.L_Currency.html">L_Currency constants</a></li><li class="chapter-item "><a href="src/libraries/L_Error.sol/error.TTSwapError.html">TTSwapError</a></li><li class="chapter-item "><a href="src/libraries/L_Good.sol/library.L_Good.html">L_Good</a></li><li class="chapter-item "><a href="src/libraries/L_GoodConfig.sol/library.L_GoodConfigLibrary.html">L_GoodConfigLibrary</a></li><li class="chapter-item "><a href="src/libraries/L_Proof.sol/library.L_Proof.html">L_Proof</a></li><li class="chapter-item "><a href="src/libraries/L_Proof.sol/library.L_ProofIdLibrary.html">L_ProofIdLibrary</a></li><li class="chapter-item "><a href="src/libraries/L_SignatureVerification.sol/library.L_SignatureVerification.html">L_SignatureVerification</a></li><li class="chapter-item "><a href="src/libraries/L_TTSTokenConfig.sol/library.L_TTSTokenConfigLibrary.html">L_TTSTokenConfigLibrary</a></li><li class="chapter-item "><a href="src/libraries/L_TTSwapUINT256.sol/error.TTSwapUINT256AddOverflow.html">TTSwapUINT256AddOverflow</a></li><li class="chapter-item "><a href="src/libraries/L_TTSwapUINT256.sol/error.TTSwapUINT256SubOverflow.html">TTSwapUINT256SubOverflow</a></li><li class="chapter-item "><a href="src/libraries/L_TTSwapUINT256.sol/error.TTSwapUINT256AddSubOverflow.html">TTSwapUINT256AddSubOverflow</a></li><li class="chapter-item "><a href="src/libraries/L_TTSwapUINT256.sol/error.TTSwapUINT256SubAddOverflow.html">TTSwapUINT256SubAddOverflow</a></li><li class="chapter-item "><a href="src/libraries/L_TTSwapUINT256.sol/error.TTSwapUINT256ToUint128Overflow.html">TTSwapUINT256ToUint128Overflow</a></li><li class="chapter-item "><a href="src/libraries/L_TTSwapUINT256.sol/error.TTSwapUINT256NotValid.html">TTSwapUINT256NotValid</a></li><li class="chapter-item "><a href="src/libraries/L_TTSwapUINT256.sol/library.L_TTSwapUINT256Library.html">L_TTSwapUINT256Library</a></li><li class="chapter-item "><a href="src/libraries/L_TTSwapUINT256.sol/function.lowerprice.html">lowerprice</a></li><li class="chapter-item "><a href="src/libraries/L_TTSwapUINT256.sol/function.toTTSwapUINT256.html">toTTSwapUINT256</a></li><li class="chapter-item "><a href="src/libraries/L_TTSwapUINT256.sol/function.mulDiv.html">mulDiv</a></li><li class="chapter-item "><a href="src/libraries/L_TTSwapUINT256.sol/function.addsub.html">addsub</a></li><li class="chapter-item "><a href="src/libraries/L_TTSwapUINT256.sol/function.subadd.html">subadd</a></li><li class="chapter-item "><a href="src/libraries/L_TTSwapUINT256.sol/function.add.html">add</a></li><li class="chapter-item "><a href="src/libraries/L_TTSwapUINT256.sol/function.toUint128.html">toUint128</a></li><li class="chapter-item "><a href="src/libraries/L_TTSwapUINT256.sol/function.sub.html">sub</a></li><li class="chapter-item "><a href="src/libraries/L_Transient.sol/library.L_Transient.html">L_Transient</a></li><li class="chapter-item "><a href="src/libraries/L_UserConfig.sol/library.L_UserConfigLibrary.html">L_UserConfigLibrary</a></li></ol></li><li class="chapter-item "><a href="src/test/index.html">❱ test</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/test/CurrencyHarness.sol/contract.CurrencyHarness.html">CurrencyHarness</a></li><li class="chapter-item "><a href="src/test/MyToken.sol/contract.MyToken.html">MyToken</a></li><li class="chapter-item "><a href="src/test/TransientHarness.sol/contract.TransientHarness.html">TransientHarness</a></li><li class="chapter-item "><a href="src/test/TransientHarness.sol/contract.RejectEthReceiver.html">RejectEthReceiver</a></li><li class="chapter-item "><a href="src/test/dai.sol/contract.Dai.html">Dai</a></li></ol></li><li class="chapter-item "><a href="src/type/index.html">❱ type</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/type/T_GoodKey.sol/struct.T_GoodKey.html">T_GoodKey</a></li><li class="chapter-item "><a href="src/type/T_GoodKey.sol/library.T_GoodKeyLibrary.html">T_GoodKeyLibrary</a></li></ol></li><li class="chapter-item "><a href="src/TTSwap_Market.sol/contract.TTSwap_Market.html">TTSwap_Market</a></li><li class="chapter-item "><a href="src/TTSwap_Market_Proxy.sol/contract.TTSwap_Market_Proxy.html">TTSwap_Market_Proxy</a></li><li class="chapter-item "><a href="src/TTSwap_Token.sol/contract.TTSwap_Token.html">TTSwap_Token</a></li><li class="chapter-item "><a href="src/TTSwap_Token_Proxy.sol/contract.TTSwap_Token_Proxy.html">TTSwap_Token_Proxy</a></li></ol>';
        // Set the current, active page, and reveal it if it's hidden
        let current_page = document.location.href.toString().split("#")[0].split("?")[0];
        if (current_page.endsWith("/")) {
            current_page += "index.html";
        }
        var links = Array.prototype.slice.call(this.querySelectorAll("a"));
        var l = links.length;
        for (var i = 0; i < l; ++i) {
            var link = links[i];
            var href = link.getAttribute("href");
            if (href && !href.startsWith("#") && !/^(?:[a-z+]+:)?\/\//.test(href)) {
                link.href = path_to_root + href;
            }
            // The "index" page is supposed to alias the first chapter in the book.
            if (link.href === current_page || (i === 0 && path_to_root === "" && current_page.endsWith("/index.html"))) {
                link.classList.add("active");
                var parent = link.parentElement;
                if (parent && parent.classList.contains("chapter-item")) {
                    parent.classList.add("expanded");
                }
                while (parent) {
                    if (parent.tagName === "LI" && parent.previousElementSibling) {
                        if (parent.previousElementSibling.classList.contains("chapter-item")) {
                            parent.previousElementSibling.classList.add("expanded");
                        }
                    }
                    parent = parent.parentElement;
                }
            }
        }
        // Track and set sidebar scroll position
        this.addEventListener('click', function(e) {
            if (e.target.tagName === 'A') {
                sessionStorage.setItem('sidebar-scroll', this.scrollTop);
            }
        }, { passive: true });
        var sidebarScrollTop = sessionStorage.getItem('sidebar-scroll');
        sessionStorage.removeItem('sidebar-scroll');
        if (sidebarScrollTop) {
            // preserve sidebar scroll position when navigating via links within sidebar
            this.scrollTop = sidebarScrollTop;
        } else {
            // scroll sidebar to current active section when navigating via "next/previous chapter" buttons
            var activeSection = document.querySelector('#sidebar .active');
            if (activeSection) {
                activeSection.scrollIntoView({ block: 'center' });
            }
        }
        // Toggle buttons
        var sidebarAnchorToggles = document.querySelectorAll('#sidebar a.toggle');
        function toggleSection(ev) {
            ev.currentTarget.parentElement.classList.toggle('expanded');
        }
        Array.from(sidebarAnchorToggles).forEach(function (el) {
            el.addEventListener('click', toggleSection);
        });
    }
}
window.customElements.define("mdbook-sidebar-scrollbox", MDBookSidebarScrollbox);
